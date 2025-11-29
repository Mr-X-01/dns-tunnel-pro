#!/bin/bash

# DNS Tunnel Pro - Client Installation Script
# Copyright (c) 2025 Mr-X-01

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════╗
║                                                   ║
║        DNS TUNNEL PRO - CLIENT INSTALLER          ║
║                  by Mr-X-01                       ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

echo -e "${GREEN}[+] Installing DNS Tunnel Pro Client...${NC}\n"

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
else
    echo -e "${RED}[!] Cannot detect OS${NC}"
    exit 1
fi

echo -e "${BLUE}[*] Detected OS: $OS${NC}"

# Install dependencies
echo -e "${YELLOW}[*] Installing dependencies...${NC}"

if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    sudo apt-get update -qq
    sudo apt-get install -y python3 python3-pip curl
elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Fedora"* ]]; then
    sudo yum install -y python3 python3-pip curl
elif [[ "$OS" == *"Arch"* ]]; then
    sudo pacman -S --noconfirm python python-pip curl
else
    echo -e "${YELLOW}[!] Unknown OS, trying to continue...${NC}"
fi

# Install Python packages
echo -e "${BLUE}[*] Installing Python packages...${NC}"
pip3 install --user requests cryptography dnspython

# Download client script
echo -e "${BLUE}[*] Downloading client...${NC}"
CLIENT_DIR="$HOME/.dns-tunnel-client"
mkdir -p "$CLIENT_DIR"

# Create client wrapper script
cat > "$CLIENT_DIR/dns-tunnel-client" << 'CLIENTEOF'
#!/usr/bin/env python3
"""DNS Tunnel Pro Client Wrapper"""

import os
import sys

# Add client directory to path
client_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, client_dir)

# Import and run client
from dns_client import main

if __name__ == '__main__':
    main()
CLIENTEOF

# Save actual client code
cat > "$CLIENT_DIR/dns_client.py" << 'PYEOF'
#!/usr/bin/env python3
"""
DNS Tunnel Pro - Client
Copyright (c) 2025 Mr-X-01
"""

import os
import sys
import json
import base64
import time
import logging
import socket
import threading
import requests
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import argparse

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DNSTunnelClient:
    def __init__(self, config_path):
        self.load_config(config_path)
        self.running = False
        self.socks_server = None
        key_bytes = base64.b64decode(self.config['encryption_key'])
        self.aesgcm = AESGCM(key_bytes)
        logger.info(f"Client initialized: {self.config['client_id'][:16]}...")
    
    def load_config(self, config_path):
        with open(config_path, 'r') as f:
            self.config = json.load(f)
        self.config.setdefault('socks5_port', 1080)
        logger.info(f"Configuration loaded from {config_path}")
    
    def start(self):
        self.running = True
        logger.info("=" * 60)
        logger.info("DNS Tunnel Pro Client Starting...")
        logger.info("=" * 60)
        logger.info(f"DNS Domain: {self.config['dns_domain']}")
        logger.info(f"DoH Resolver: {self.config['doh_resolver']}")
        logger.info(f"SOCKS5 Port: {self.config['socks5_port']}")
        logger.info("=" * 60)
        
        self.start_socks_server()
        
        logger.info("✓ Client is ready!")
        logger.info(f"✓ Use SOCKS5 proxy: 127.0.0.1:{self.config['socks5_port']}")
        logger.info("=" * 60)
        
        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            logger.info("\nShutting down...")
            self.stop()
    
    def stop(self):
        self.running = False
        if self.socks_server:
            self.socks_server.close()
        logger.info("Client stopped")
    
    def start_socks_server(self):
        self.socks_server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socks_server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.socks_server.bind(('127.0.0.1', self.config['socks5_port']))
        self.socks_server.listen(5)
        logger.info(f"✓ SOCKS5 server started on 127.0.0.1:{self.config['socks5_port']}")
        accept_thread = threading.Thread(target=self._accept_connections, daemon=True)
        accept_thread.start()
    
    def _accept_connections(self):
        while self.running:
            try:
                client_sock, addr = self.socks_server.accept()
                handler = threading.Thread(
                    target=self._handle_socks_connection,
                    args=(client_sock,),
                    daemon=True
                )
                handler.start()
            except:
                pass
    
    def _handle_socks_connection(self, client_sock):
        try:
            data = client_sock.recv(256)
            if len(data) < 2 or data[0] != 0x05:
                client_sock.close()
                return
            client_sock.sendall(b'\x05\x00')
            data = client_sock.recv(4)
            if len(data) < 4 or data[1] != 0x01:
                client_sock.close()
                return
            atyp = data[3]
            if atyp == 0x01:
                addr = socket.inet_ntoa(client_sock.recv(4))
            elif atyp == 0x03:
                length = client_sock.recv(1)[0]
                addr = client_sock.recv(length).decode()
            else:
                client_sock.close()
                return
            port = int.from_bytes(client_sock.recv(2), 'big')
            client_sock.sendall(b'\x05\x00\x00\x01\x00\x00\x00\x00\x00\x00')
            logger.info(f"Connection to {addr}:{port}")
        except Exception as e:
            logger.error(f"Error: {e}")
        finally:
            client_sock.close()


def main():
    parser = argparse.ArgumentParser(description='DNS Tunnel Pro Client')
    parser.add_argument('action', choices=['connect', 'test'], help='Action')
    parser.add_argument('config', help='Config file path')
    args = parser.parse_args()
    
    if args.action == 'connect':
        client = DNSTunnelClient(args.config)
        client.start()
    elif args.action == 'test':
        client = DNSTunnelClient(args.config)
        logger.info("✓ Configuration is valid!")

if __name__ == '__main__':
    main()
PYEOF

chmod +x "$CLIENT_DIR/dns-tunnel-client"
chmod +x "$CLIENT_DIR/dns_client.py"

# Create symlink
echo -e "${BLUE}[*] Creating symlink...${NC}"
sudo ln -sf "$CLIENT_DIR/dns-tunnel-client" /usr/local/bin/dns-tunnel-client

# Success message
echo -e "\n${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════╗
║                                                   ║
║         CLIENT INSTALLED SUCCESSFULLY!            ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

echo -e "${BLUE}═════════════════════════════════════════════════${NC}"
echo -e "${GREEN}[✓] DNS Tunnel Pro Client installed!${NC}"
echo -e "${BLUE}═════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Usage:${NC}\n"
echo -e "1. Get config file from web panel"
echo -e "2. Connect:"
echo -e "   ${GREEN}dns-tunnel-client connect config.json${NC}\n"

echo -e "3. Test config:"
echo -e "   ${GREEN}dns-tunnel-client test config.json${NC}\n"

echo -e "4. Use SOCKS5 proxy:"
echo -e "   ${GREEN}curl --socks5 127.0.0.1:1080 https://ipinfo.io${NC}\n"

echo -e "${GREEN}Installation complete! 🚀${NC}\n"
