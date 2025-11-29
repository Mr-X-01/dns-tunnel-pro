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

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DNSTunnelClient:
    """DNS Tunnel Client"""
    
    def __init__(self, config_path):
        """Initialize client with config"""
        self.load_config(config_path)
        self.running = False
        self.socks_server = None
        
        # Initialize encryption
        key_bytes = base64.b64decode(self.config['encryption_key'])
        self.aesgcm = AESGCM(key_bytes)
        
        logger.info(f"Client initialized: {self.config['client_id'][:16]}...")
    
    def load_config(self, config_path):
        """Load configuration from JSON file"""
        try:
            with open(config_path, 'r') as f:
                self.config = json.load(f)
            
            required_keys = ['client_id', 'encryption_key', 'dns_domain', 'doh_resolver']
            for key in required_keys:
                if key not in self.config:
                    raise ValueError(f"Missing required config key: {key}")
            
            # Set defaults
            self.config.setdefault('socks5_port', 1080)
            
            logger.info(f"Configuration loaded from {config_path}")
            
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            sys.exit(1)
    
    def start(self):
        """Start the tunnel client"""
        self.running = True
        logger.info("=" * 60)
        logger.info("DNS Tunnel Pro Client Starting...")
        logger.info("=" * 60)
        logger.info(f"DNS Domain: {self.config['dns_domain']}")
        logger.info(f"DoH Resolver: {self.config['doh_resolver']}")
        logger.info(f"SOCKS5 Port: {self.config['socks5_port']}")
        logger.info("=" * 60)
        
        # Start SOCKS5 proxy server
        self.start_socks_server()
        
        logger.info("Client is ready!")
        logger.info(f"Use SOCKS5 proxy: 127.0.0.1:{self.config['socks5_port']}")
        logger.info("=" * 60)
        
        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            logger.info("\nShutting down...")
            self.stop()
    
    def stop(self):
        """Stop the client"""
        self.running = False
        if self.socks_server:
            self.socks_server.close()
        logger.info("Client stopped")
    
    def start_socks_server(self):
        """Start local SOCKS5 server"""
        try:
            self.socks_server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socks_server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.socks_server.bind(('127.0.0.1', self.config['socks5_port']))
            self.socks_server.listen(5)
            
            logger.info(f"SOCKS5 server started on 127.0.0.1:{self.config['socks5_port']}")
            
            # Accept connections in background
            accept_thread = threading.Thread(target=self._accept_connections, daemon=True)
            accept_thread.start()
            
        except Exception as e:
            logger.error(f"Failed to start SOCKS5 server: {e}")
            sys.exit(1)
    
    def _accept_connections(self):
        """Accept incoming SOCKS5 connections"""
        while self.running:
            try:
                client_sock, addr = self.socks_server.accept()
                logger.debug(f"New connection from {addr}")
                
                # Handle in new thread
                handler = threading.Thread(
                    target=self._handle_socks_connection,
                    args=(client_sock,),
                    daemon=True
                )
                handler.start()
                
            except Exception as e:
                if self.running:
                    logger.error(f"Error accepting connection: {e}")
    
    def _handle_socks_connection(self, client_sock):
        """Handle SOCKS5 connection"""
        try:
            # SOCKS5 handshake
            data = client_sock.recv(256)
            if len(data) < 2 or data[0] != 0x05:
                client_sock.close()
                return
            
            # No authentication
            client_sock.sendall(b'\x05\x00')
            
            # Get request
            data = client_sock.recv(4)
            if len(data) < 4:
                client_sock.close()
                return
            
            cmd = data[1]
            atyp = data[3]
            
            if cmd != 0x01:  # Only support CONNECT
                client_sock.sendall(b'\x05\x07\x00\x01\x00\x00\x00\x00\x00\x00')
                client_sock.close()
                return
            
            # Parse address
            if atyp == 0x01:  # IPv4
                addr = socket.inet_ntoa(client_sock.recv(4))
            elif atyp == 0x03:  # Domain
                length = client_sock.recv(1)[0]
                addr = client_sock.recv(length).decode()
            else:
                client_sock.sendall(b'\x05\x08\x00\x01\x00\x00\x00\x00\x00\x00')
                client_sock.close()
                return
            
            # Get port
            port = int.from_bytes(client_sock.recv(2), 'big')
            
            logger.debug(f"CONNECT {addr}:{port}")
            
            # Send success response
            client_sock.sendall(b'\x05\x00\x00\x01\x00\x00\x00\x00\x00\x00')
            
            # Proxy the connection through DNS tunnel
            self._proxy_connection(client_sock, addr, port)
            
        except Exception as e:
            logger.error(f"SOCKS connection error: {e}")
        finally:
            client_sock.close()
    
    def _proxy_connection(self, client_sock, target_host, target_port):
        """Proxy connection through DNS tunnel"""
        try:
            # For now, implement simple HTTP proxy
            # In production, this would use full bidirectional tunneling
            
            # Read client request
            request_data = b''
            client_sock.settimeout(5)
            
            while True:
                try:
                    chunk = client_sock.recv(4096)
                    if not chunk:
                        break
                    request_data += chunk
                    
                    # Check if HTTP request is complete
                    if b'\r\n\r\n' in request_data:
                        break
                except socket.timeout:
                    break
            
            if not request_data:
                return
            
            # Parse HTTP request
            try:
                request_line = request_data.split(b'\r\n')[0].decode()
                method, path, _ = request_line.split(' ')
                
                # Build full URL
                url = f"http://{target_host}:{target_port}{path}"
                
                # Send through DNS tunnel
                response_data = self.send_request(url, method, request_data)
                
                if response_data:
                    # Send response back to client
                    client_sock.sendall(response_data)
                    
            except Exception as e:
                logger.debug(f"HTTP parsing error: {e}")
                
        except Exception as e:
            logger.error(f"Proxy error: {e}")
    
    def send_request(self, url, method='GET', data=None):
        """Send HTTP request through DNS tunnel"""
        try:
            # Prepare request payload
            request_payload = {
                'url': url,
                'method': method,
                'headers': {},
                'body': base64.b64encode(data).decode() if data else None
            }
            
            # Encrypt payload
            payload_json = json.dumps(request_payload)
            nonce = os.urandom(12)
            ciphertext = self.aesgcm.encrypt(nonce, payload_json.encode(), None)
            encrypted_payload = base64.b64encode(nonce + ciphertext).decode()
            
            # Prepare DNS query data
            tunnel_data = {
                'client_id': self.config['client_id'],
                'payload': encrypted_payload
            }
            
            # Encode for DNS subdomain
            encoded = self._encode_for_dns(tunnel_data)
            
            # Make DoH query
            response = self._query_doh(encoded)
            
            if response and 'payload' in response:
                # Decrypt response
                encrypted_response = base64.b64decode(response['payload'])
                nonce = encrypted_response[:12]
                ciphertext = encrypted_response[12:]
                
                plaintext = self.aesgcm.decrypt(nonce, ciphertext, None)
                response_data = json.loads(plaintext)
                
                # Extract response body
                if 'body' in response_data:
                    return base64.b64decode(response_data['body'])
            
            return None
            
        except Exception as e:
            logger.error(f"Request error: {e}")
            return None
    
    def _encode_for_dns(self, data):
        """Encode data for DNS subdomain"""
        # Serialize to JSON
        json_data = json.dumps(data)
        
        # Base64 encode (DNS-safe)
        encoded = base64.b64encode(json_data.encode()).decode()
        encoded = encoded.replace('+', '-').replace('/', '_').replace('=', '')
        
        # Split into DNS labels (max 63 chars each)
        labels = [encoded[i:i+63] for i in range(0, len(encoded), 63)]
        
        # Create subdomain
        subdomain = '.'.join(labels) + '.' + self.config['dns_domain']
        
        return subdomain
    
    def _query_doh(self, domain):
        """Query DoH resolver"""
        try:
            params = {
                'name': domain,
                'type': 'TXT'
            }
            
            headers = {
                'Accept': 'application/dns-json'
            }
            
            response = requests.get(
                self.config['doh_resolver'],
                params=params,
                headers=headers,
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                
                # Extract TXT record
                if 'Answer' in data:
                    for answer in data['Answer']:
                        if answer['type'] == 16:  # TXT record
                            txt_data = answer['data'].strip('"')
                            return self._decode_from_dns(txt_data)
            
            return None
            
        except Exception as e:
            logger.debug(f"DoH query error: {e}")
            return None
    
    def _decode_from_dns(self, encoded):
        """Decode data from DNS response"""
        try:
            # Restore base64
            encoded = encoded.replace('-', '+').replace('_', '/')
            padding = 4 - (len(encoded) % 4)
            if padding != 4:
                encoded += '=' * padding
            
            # Decode
            decoded = base64.b64decode(encoded)
            return json.loads(decoded)
            
        except Exception as e:
            logger.debug(f"Decode error: {e}")
            return None


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='DNS Tunnel Pro Client')
    parser.add_argument('action', choices=['connect', 'test'], help='Action to perform')
    parser.add_argument('config', help='Path to configuration file')
    
    args = parser.parse_args()
    
    if args.action == 'connect':
        client = DNSTunnelClient(args.config)
        client.start()
    elif args.action == 'test':
        client = DNSTunnelClient(args.config)
        logger.info("Testing connection...")
        response = client.send_request('http://example.com', 'GET')
        if response:
            logger.info(f"✓ Connection test successful! ({len(response)} bytes received)")
        else:
            logger.error("✗ Connection test failed")


if __name__ == '__main__':
    main()
