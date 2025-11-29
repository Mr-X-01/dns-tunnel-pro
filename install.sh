#!/bin/bash

# DNS Tunnel Pro - Server Installation Script
# Copyright (c) 2025 Mr-X-01

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Ask for domain
echo -e "${YELLOW}"
read -p "[?] Enter your domain (e.g., tunnel.yourdomain.com): " DNS_DOMAIN
echo -e "${NC}"

if [ -z "$DNS_DOMAIN" ]; then
    echo -e "${RED}[!] Domain cannot be empty${NC}"
    exit 1
fi

# Ask for admin password
echo -e "${YELLOW}"
read -sp "[?] Set admin password (default: admin123): " ADMIN_PASSWORD
echo -e "${NC}"
if [ -z "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD="admin123"
fi

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

# Install Python dependencies
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

# Create directories
mkdir -p server/{database,logs,ssl,config}
mkdir -p client_configs

# Generate SSL certificate
echo -e "${BLUE}[*] Generating SSL certificate...${NC}"
openssl req -x509 -newkey rsa:4096 -nodes \
    -keyout server/ssl/key.pem \
    -out server/ssl/cert.pem \
    -days 365 \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=$DNS_DOMAIN" 2>/dev/null

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
  port: 8443
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
CONFEOF

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

echo -e "${BLUE}═════════════════════════════════════════════════${NC}"
echo -e "${GREEN}[✓] DNS Tunnel Pro Server installed!${NC}"
echo -e "${BLUE}═════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Next Steps:${NC}\n"
echo -e "1. Configure your DNS records:"
echo -e "   ${BLUE}${DNS_DOMAIN}.  IN  NS  ns.${DNS_DOMAIN}.${NC}"
echo -e "   ${BLUE}ns.${DNS_DOMAIN}.  IN  A  ${SERVER_IP}${NC}\n"

echo -e "2. Start the service:"
echo -e "   ${GREEN}systemctl start dns-tunnel${NC}"
echo -e "   ${GREEN}systemctl enable dns-tunnel${NC}\n"

echo -e "3. Access Web Panel:"
echo -e "   ${BLUE}https://${SERVER_IP}:8443${NC}"
echo -e "   Username: ${GREEN}admin${NC}"
echo -e "   Password: ${GREEN}${ADMIN_PASSWORD}${NC}\n"

echo -e "4. Check logs:"
echo -e "   ${BLUE}tail -f /opt/dns-tunnel-pro/server/logs/server.log${NC}\n"

echo -e "${YELLOW}⚠  Don't forget to change admin password after first login!${NC}\n"

# Ask to start service
read -p "Start DNS Tunnel service now? [Y/n]: " START_NOW
if [[ "$START_NOW" != "n" ]] && [[ "$START_NOW" != "N" ]]; then
    systemctl enable dns-tunnel
    systemctl start dns-tunnel
    echo -e "\n${GREEN}[✓] Service started!${NC}"
    echo -e "${BLUE}[*] Status: $(systemctl is-active dns-tunnel)${NC}\n"
fi

echo -e "${GREEN}Installation complete! 🚀${NC}\n"
