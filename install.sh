#!/bin/bash

################################################################################
# DNS Tunnel Pro - Professional Server Installation Script
# Copyright (c) 2025 Mr-X-01
# 
# Features:
# - Let's Encrypt SSL certificates via Certbot
# - Automatic firewall (UFW) configuration
# - Custom port selection for web panel
# - Full automation with professional setup
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/dns-tunnel-pro"
LOG_FILE="/tmp/dns-tunnel-install.log"

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════╗
║                                                   ║
║        DNS TUNNEL PRO - SERVER INSTALLER          ║
║                  by Mr-X-01                       ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] This script must be run as root${NC}" 
   exit 1
fi

echo -e "${GREEN}[+] Starting DNS Tunnel Pro installation...${NC}\n"

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo -e "${RED}[!] Cannot detect OS${NC}"
    exit 1
fi

echo -e "${BLUE}[*] Detected OS: $OS $VER${NC}"

# Update system
echo -e "${YELLOW}[*] Updating system packages...${NC}"
if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    apt-get update -qq
    apt-get install -y python3 python3-pip python3-venv git curl wget dnsutils net-tools
elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
    yum update -y -q
    yum install -y python3 python3-pip git curl wget bind-utils net-tools
else
    echo -e "${YELLOW}[!] Unsupported OS, trying to continue anyway...${NC}"
fi

# Get server IP
SERVER_IP=$(curl -s ifconfig.me)
echo -e "${GREEN}[+] Server IP: $SERVER_IP${NC}"

# Validate domain format
validate_domain() {
    local domain=$1
    # Domain must contain at least one dot and valid characters
    if [[ ! "$domain" =~ \. ]]; then
        return 1
    fi
    if [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Generate random port
generate_random_port() {
    shuf -i 10000-60000 -n 1
}

# Check if port is available
check_port() {
    local port=$1
    if ss -tuln | grep -q ":$port " 2>/dev/null; then
        return 1
    else
        return 0
    fi
}

echo -e "\n${CYAN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           CONFIGURATION REQUIRED                  ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════╝${NC}\n"

# Ask for domain
while true; do
    echo -e "${YELLOW}"
    read -p "[?] Enter your domain (e.g., tunnel.example.com): " DNS_DOMAIN
    echo -e "${NC}"
    
    if [ -z "$DNS_DOMAIN" ]; then
        echo -e "${RED}[!] Domain cannot be empty${NC}"
        continue
    fi
    
    if validate_domain "$DNS_DOMAIN"; then
        echo -e "${GREEN}[✓] Domain validated: $DNS_DOMAIN${NC}"
        break
    else
        echo -e "${RED}[!] Invalid domain format. Please try again.${NC}"
    fi
done

# Ask for email (for Let's Encrypt)
while true; do
    echo -e "${YELLOW}"
    read -p "[?] Enter your email for Let's Encrypt SSL: " LETSENCRYPT_EMAIL
    echo -e "${NC}"
    
    if [ -z "$LETSENCRYPT_EMAIL" ]; then
        echo -e "${RED}[!] Email cannot be empty${NC}"
        continue
    fi
    
    if [[ $LETSENCRYPT_EMAIL =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${GREEN}[✓] Email validated: $LETSENCRYPT_EMAIL${NC}"
        break
    else
        echo -e "${RED}[!] Invalid email format. Please try again.${NC}"
    fi
done

# Ask for web panel port
DEFAULT_PORT=$(generate_random_port)
echo -e "${YELLOW}"
read -p "[?] Web panel port (default: $DEFAULT_PORT, range: 10000-60000): " WEB_PANEL_PORT
echo -e "${NC}"

if [ -z "$WEB_PANEL_PORT" ]; then
    WEB_PANEL_PORT=$DEFAULT_PORT
fi

# Validate port
if ! [[ "$WEB_PANEL_PORT" =~ ^[0-9]+$ ]] || [ "$WEB_PANEL_PORT" -lt 10000 ] || [ "$WEB_PANEL_PORT" -gt 60000 ]; then
    echo -e "${RED}[!] Invalid port. Using default: $DEFAULT_PORT${NC}"
    WEB_PANEL_PORT=$DEFAULT_PORT
fi

# Check if port is available
if ! check_port $WEB_PANEL_PORT; then
    echo -e "${YELLOW}[!] Port $WEB_PANEL_PORT is already in use${NC}"
    WEB_PANEL_PORT=$(generate_random_port)
    echo -e "${GREEN}[+] Using available port: $WEB_PANEL_PORT${NC}"
fi

echo -e "${GREEN}[✓] Web panel will run on port: $WEB_PANEL_PORT${NC}"

# Ask for admin password
while true; do
    echo -e "${YELLOW}"
    read -sp "[?] Set admin password (min 8 characters): " ADMIN_PASSWORD
    echo -e "${NC}"
    
    if [ -z "$ADMIN_PASSWORD" ]; then
        echo -e "${RED}[!] Password cannot be empty${NC}"
        continue
    fi
    
    if [ ${#ADMIN_PASSWORD} -lt 8 ]; then
        echo -e "${RED}[!] Password must be at least 8 characters${NC}"
        continue
    fi
    
    echo -e "${YELLOW}"
    read -sp "[?] Confirm password: " ADMIN_PASSWORD_CONFIRM
    echo -e "${NC}"
    
    if [ "$ADMIN_PASSWORD" != "$ADMIN_PASSWORD_CONFIRM" ]; then
        echo -e "${RED}[!] Passwords do not match${NC}"
        continue
    fi
    
    echo -e "${GREEN}[✓] Password set successfully${NC}"
    break
done

# Create directories
echo -e "${BLUE}[*] Creating directory structure...${NC}"
mkdir -p /opt/dns-tunnel-pro
cd /opt/dns-tunnel-pro

# Clone or copy files
if [ -d "/tmp/dns-tunnel-pro" ]; then
    cp -r /tmp/dns-tunnel-pro/* .
else
    echo -e "${YELLOW}[*] Copying current directory files...${NC}"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cp -r "$SCRIPT_DIR"/* .
fi

# Create Python virtual environment
echo -e "${BLUE}[*] Setting up Python environment...${NC}"
python3 -m venv venv
source venv/bin/activate

# Install Certbot for Let's Encrypt
echo -e "${BLUE}[*] Installing Certbot for SSL certificates...${NC}"
if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    apt-get install -y certbot python3-certbot-nginx >/dev/null 2>&1
elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
    yum install -y certbot python3-certbot-nginx >/dev/null 2>&1
fi

echo -e "${GREEN}[✓] Certbot installed${NC}"

# Install Python packages
echo -e "${BLUE}[*] Installing Python packages...${NC}"
cat > requirements.txt << 'PYREQ'
Flask==2.3.3
Flask-Login==0.6.2
Flask-SQLAlchemy==3.0.5
dnslib==0.9.23
cryptography==41.0.3
requests==2.31.0
PyYAML==6.0.1
dnspython==2.4.2
gunicorn==21.2.0
PYREQ

pip install -q --upgrade pip
pip install -q -r requirements.txt

echo -e "${GREEN}[✓] Python packages installed${NC}"

# Create directories
mkdir -p server/{database,logs,ssl,config}
mkdir -p client_configs

# Configure UFW Firewall
echo -e "${BLUE}[*] Configuring firewall (UFW)...${NC}"
if command -v ufw >/dev/null 2>&1; then
    # Enable UFW if not enabled
    ufw --force enable >/dev/null 2>&1
    
    # Default policies
    ufw default deny incoming >/dev/null 2>&1
    ufw default allow outgoing >/dev/null 2>&1
    
    # Allow SSH (important!)
    ufw allow 22/tcp comment 'SSH' >/dev/null 2>&1
    
    # Allow DNS (UDP port 53)
    ufw allow 53/udp comment 'DNS Tunnel' >/dev/null 2>&1
    
    # Allow web panel port
    ufw allow $WEB_PANEL_PORT/tcp comment 'Web Panel' >/dev/null 2>&1
    
    # Allow HTTP/HTTPS for Let's Encrypt
    ufw allow 80/tcp comment 'HTTP (Let\'s Encrypt)' >/dev/null 2>&1
    ufw allow 443/tcp comment 'HTTPS' >/dev/null 2>&1
    
    # Reload UFW
    ufw reload >/dev/null 2>&1
    
    echo -e "${GREEN}[✓] Firewall configured${NC}"
    echo -e "${GREEN}    - Port 53/UDP: DNS Server${NC}"
    echo -e "${GREEN}    - Port $WEB_PANEL_PORT/TCP: Web Panel${NC}"
    echo -e "${GREEN}    - Port 80,443/TCP: HTTPS${NC}"
else
    echo -e "${YELLOW}[!] UFW not found, skipping firewall configuration${NC}"
fi

# Generate Let's Encrypt SSL certificate
echo -e "${BLUE}[*] Generating Let's Encrypt SSL certificate...${NC}"
echo -e "${YELLOW}[*] Please ensure your domain $DNS_DOMAIN points to $SERVER_IP${NC}"

# Try to get Let's Encrypt certificate
if certbot certonly --standalone --non-interactive --agree-tos \
    --email "$LETSENCRYPT_EMAIL" \
    -d "$DNS_DOMAIN" \
    --http-01-port 80 >/dev/null 2>&1; then
    
    echo -e "${GREEN}[✓] Let's Encrypt certificate obtained successfully!${NC}"
    
    # Copy certificates to our directory
    cp "/etc/letsencrypt/live/$DNS_DOMAIN/fullchain.pem" server/ssl/cert.pem
    cp "/etc/letsencrypt/live/$DNS_DOMAIN/privkey.pem" server/ssl/key.pem
    
    SSL_METHOD="Let's Encrypt"
    
    # Create renewal hook
    cat > /etc/letsencrypt/renewal-hooks/deploy/dns-tunnel.sh << 'RENEWEOF'
#!/bin/bash
cp /etc/letsencrypt/live/$DNS_DOMAIN/fullchain.pem /opt/dns-tunnel-pro/server/ssl/cert.pem
cp /etc/letsencrypt/live/$DNS_DOMAIN/privkey.pem /opt/dns-tunnel-pro/server/ssl/key.pem
systemctl restart dns-tunnel
RENEWEOF
    chmod +x /etc/letsencrypt/renewal-hooks/deploy/dns-tunnel.sh
    
else
    echo -e "${YELLOW}[!] Let's Encrypt certificate failed. Using self-signed certificate.${NC}"
    echo -e "${YELLOW}[!] Make sure your domain points to this server and ports 80/443 are open.${NC}"
    
    # Generate self-signed certificate as fallback
    openssl req -x509 -newkey rsa:4096 -nodes \
        -keyout server/ssl/key.pem \
        -out server/ssl/cert.pem \
        -days 365 \
        -subj "/C=US/ST=State/L=City/O=DNS-Tunnel-Pro/CN=$DNS_DOMAIN" 2>/dev/null
    
    SSL_METHOD="Self-signed (temporary)"
fi

# Create config file
echo -e "${BLUE}[*] Creating configuration...${NC}"
cat > server/config/settings.yml << CONFEOF
dns:
  port: 53
  domain: ${DNS_DOMAIN}
  doh_resolver: https://common.dot.dns.yandex.net/dns-query
  buffer_size: 512

web_panel:
  host: 0.0.0.0
  port: ${WEB_PANEL_PORT}
  ssl_cert: ssl/cert.pem
  ssl_key: ssl/key.pem
  secret_key: $(openssl rand -hex 32)
  admin_user: admin
  admin_password: ${ADMIN_PASSWORD}

proxy:
  socks5_host: 127.0.0.1
  socks5_port: 1080

logging:
  level: INFO
  file: logs/server.log
  max_bytes: 10485760
  backup_count: 5

security:
  encryption: aes-256-gcm
  max_clients: 100
  rate_limit: 1000

server:
  ip: ${SERVER_IP}
  domain: ${DNS_DOMAIN}
  ssl_method: ${SSL_METHOD}
CONFEOF

echo -e "${GREEN}[✓] Configuration created${NC}"

# Create systemd service
echo -e "${BLUE}[*] Creating systemd service...${NC}"
cat > /etc/systemd/system/dns-tunnel.service << 'SVCEOF'
[Unit]
Description=DNS Tunnel Pro Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/dns-tunnel-pro
ExecStart=/opt/dns-tunnel-pro/venv/bin/python3 /opt/dns-tunnel-pro/server/main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SVCEOF

# Reload systemd
systemctl daemon-reload

# Set permissions
chmod +x server/*.py
chmod 600 server/config/settings.yml
chmod 600 server/ssl/*.pem

# Save installation info
cat > /opt/dns-tunnel-pro/INSTALL_INFO.txt << INFOEOF
╔═══════════════════════════════════════════════════╗
║        DNS TUNNEL PRO - INSTALLATION INFO         ║
╚═══════════════════════════════════════════════════╝

Installed: $(date)

SERVER INFORMATION:
  IP Address: ${SERVER_IP}
  Domain: ${DNS_DOMAIN}
  SSL Method: ${SSL_METHOD}

WEB PANEL:
  URL: https://${DNS_DOMAIN}:${WEB_PANEL_PORT}
  Port: ${WEB_PANEL_PORT}
  Username: admin
  Password: ${ADMIN_PASSWORD}

DNS CONFIGURATION:
  Add these records to your domain:
  ${DNS_DOMAIN}.     IN  NS  ns.${DNS_DOMAIN}.
  ns.${DNS_DOMAIN}.  IN  A   ${SERVER_IP}

FIREWALL PORTS:
  53/UDP  - DNS Server
  ${WEB_PANEL_PORT}/TCP - Web Panel
  80/TCP  - HTTP (Let's Encrypt)
  443/TCP - HTTPS

SERVICE COMMANDS:
  Start:   systemctl start dns-tunnel
  Stop:    systemctl stop dns-tunnel
  Restart: systemctl restart dns-tunnel
  Status:  systemctl status dns-tunnel
  Logs:    journalctl -u dns-tunnel -f

CERTIFICATE RENEWAL:
  Certificates will auto-renew via certbot
  Manual renewal: certbot renew

INFOEOF

chmod 600 /opt/dns-tunnel-pro/INSTALL_INFO.txt

# Display completion message
echo -e "\n${GREEN}"
cat << "DONEEOF"
╔═══════════════════════════════════════════════════╗
║                                                   ║
║         INSTALLATION COMPLETED SUCCESSFULLY!      ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
DONEEOF
echo -e "${NC}\n"

echo -e "${CYAN}═════════════════════════════════════════════════${NC}"
echo -e "${GREEN}[✓] DNS Tunnel Pro Server Installed!${NC}"
echo -e "${CYAN}═════════════════════════════════════════════════${NC}\n"

echo -e "${MAGENTA}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║           SERVER INFORMATION                  ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}Server IP:${NC}      ${GREEN}${SERVER_IP}${NC}"
echo -e "${CYAN}Domain:${NC}         ${GREEN}${DNS_DOMAIN}${NC}"
echo -e "${CYAN}SSL Method:${NC}     ${GREEN}${SSL_METHOD}${NC}"
echo -e "${CYAN}Web Panel:${NC}      ${GREEN}https://${DNS_DOMAIN}:${WEB_PANEL_PORT}${NC}\n"

echo -e "${MAGENTA}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║           NEXT STEPS                          ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}1. Configure DNS Records:${NC}"
echo -e "   Add these to your domain DNS settings:"
echo -e "   ${BLUE}${DNS_DOMAIN}.     IN  NS  ns.${DNS_DOMAIN}.${NC}"
echo -e "   ${BLUE}ns.${DNS_DOMAIN}.  IN  A   ${SERVER_IP}${NC}\n"

echo -e "${YELLOW}2. Start the Service:${NC}"
echo -e "   ${GREEN}systemctl start dns-tunnel${NC}"
echo -e "   ${GREEN}systemctl enable dns-tunnel${NC}\n"

echo -e "${YELLOW}3. Access Web Panel:${NC}"
echo -e "   URL:      ${BLUE}https://${DNS_DOMAIN}:${WEB_PANEL_PORT}${NC}"
echo -e "   Username: ${GREEN}admin${NC}"
echo -e "   Password: ${GREEN}${ADMIN_PASSWORD}${NC}\n"

echo -e "${YELLOW}4. Firewall Status:${NC}"
echo -e "   ${GREEN}✓ Port 53/UDP   - DNS Server${NC}"
echo -e "   ${GREEN}✓ Port ${WEB_PANEL_PORT}/TCP - Web Panel${NC}"
echo -e "   ${GREEN}✓ Port 80,443   - HTTPS${NC}\n"

echo -e "${YELLOW}5. View Logs:${NC}"
echo -e "   ${BLUE}journalctl -u dns-tunnel -f${NC}"
echo -e "   ${BLUE}tail -f /opt/dns-tunnel-pro/server/logs/server.log${NC}\n"

echo -e "${CYAN}Installation info saved to:${NC}"
echo -e "${BLUE}/opt/dns-tunnel-pro/INSTALL_INFO.txt${NC}\n"

echo -e "${RED}⚠  IMPORTANT: Change admin password after first login!${NC}\n"

# Ask to start service
read -p "Start DNS Tunnel service now? [Y/n]: " START_NOW
if [[ "$START_NOW" != "n" ]] && [[ "$START_NOW" != "N" ]]; then
    systemctl enable dns-tunnel
    systemctl start dns-tunnel
    echo -e "\n${GREEN}[✓] Service started!${NC}"
    echo -e "${BLUE}[*] Status: $(systemctl is-active dns-tunnel)${NC}\n"
fi

echo -e "${GREEN}Installation complete! 🚀${NC}\n"
