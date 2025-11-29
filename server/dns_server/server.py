"""DNS Tunnel Server - Core functionality"""

import socket
import threading
import logging
import base64
import json
from dnslib import DNSRecord, DNSHeader, RR, QTYPE, A
from dnslib.server import DNSServer, BaseResolver
import requests
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2
import os

logger = logging.getLogger(__name__)


class DNSTunnelResolver(BaseResolver):
    """Custom DNS resolver with tunneling support"""
    
    def __init__(self, config, tunnel_server):
        self.config = config
        self.tunnel_server = tunnel_server
        self.domain = config['dns']['domain']
        self.doh_resolver = config['dns']['doh_resolver']
        
    def resolve(self, request, handler):
        """Resolve DNS request"""
        reply = request.reply()
        qname = str(request.q.qname)
        qtype = QTYPE[request.q.qtype]
        
        logger.debug(f"DNS Query: {qname} ({qtype})")
        
        # Check if this is our tunnel domain
        if self.domain in qname:
            # Extract tunnel data from subdomain
            try:
                subdomain = qname.replace(f'.{self.domain}.', '').replace(f'.{self.domain}', '')
                
                # Decode tunnel data
                if subdomain and subdomain != self.domain:
                    data = self._decode_tunnel_data(subdomain)
                    if data:
                        # Process tunnel request
                        response = self.tunnel_server.process_request(data)
                        
                        # Encode response in DNS answer
                        encoded_response = self._encode_tunnel_response(response)
                        
                        # Add to reply
                        reply.add_answer(
                            RR(qname, QTYPE.TXT, rdata=encoded_response, ttl=0)
                        )
                        return reply
                
                # Default response for tunnel domain
                reply.add_answer(
                    RR(qname, QTYPE.A, rdata=A('127.0.0.1'), ttl=300)
                )
                
            except Exception as e:
                logger.error(f"Tunnel processing error: {e}")
                reply.add_answer(
                    RR(qname, QTYPE.A, rdata=A('127.0.0.1'), ttl=60)
                )
        else:
            # Forward to DoH resolver
            try:
                upstream_reply = self._query_doh(qname, qtype)
                if upstream_reply:
                    return upstream_reply
            except Exception as e:
                logger.error(f"DoH query error: {e}")
        
        return reply
    
    def _decode_tunnel_data(self, subdomain):
        """Decode data from DNS subdomain"""
        try:
            # Remove any trailing dots and split by dots
            parts = subdomain.strip('.').split('.')
            
            # Reconstruct base64 data
            encoded = ''.join(parts)
            
            # Decode base64 (DNS-safe alphabet)
            encoded = encoded.replace('-', '+').replace('_', '/')
            padding = 4 - (len(encoded) % 4)
            if padding != 4:
                encoded += '=' * padding
            
            decoded = base64.b64decode(encoded)
            return json.loads(decoded)
        except Exception as e:
            logger.debug(f"Failed to decode tunnel data: {e}")
            return None
    
    def _encode_tunnel_response(self, response):
        """Encode response data for DNS reply"""
        try:
            # Serialize to JSON
            json_data = json.dumps(response)
            
            # Encode to base64
            encoded = base64.b64encode(json_data.encode()).decode()
            
            # Make DNS-safe
            encoded = encoded.replace('+', '-').replace('/', '_').replace('=', '')
            
            # Split into chunks if needed (DNS TXT record limit)
            max_chunk = 255
            chunks = [encoded[i:i+max_chunk] for i in range(0, len(encoded), max_chunk)]
            
            return chunks[0] if chunks else ''
        except Exception as e:
            logger.error(f"Failed to encode response: {e}")
            return ''
    
    def _query_doh(self, qname, qtype):
        """Query upstream DoH resolver"""
        try:
            params = {
                'name': qname,
                'type': qtype
            }
            
            headers = {
                'Accept': 'application/dns-json'
            }
            
            response = requests.get(
                self.doh_resolver,
                params=params,
                headers=headers,
                timeout=5
            )
            
            if response.status_code == 200:
                data = response.json()
                
                # Build DNS reply from DoH response
                reply = DNSRecord(DNSHeader(id=0, qr=1, aa=1, ra=1))
                
                if 'Answer' in data:
                    for answer in data['Answer']:
                        if answer['type'] == 1:  # A record
                            reply.add_answer(
                                RR(qname, QTYPE.A, rdata=A(answer['data']), ttl=answer.get('TTL', 300))
                            )
                
                return reply
                
        except Exception as e:
            logger.debug(f"DoH query failed: {e}")
        
        return None


class DNSTunnelServer:
    """Main DNS Tunnel Server"""
    
    def __init__(self, config):
        self.config = config
        self.clients = {}
        self.client_keys = {}
        self.running = False
        
        # Create resolver
        self.resolver = DNSTunnelResolver(config, self)
        
        # DNS server
        self.dns_server = DNSServer(
            self.resolver,
            port=config['dns']['port'],
            address='0.0.0.0'
        )
        
        logger.info("DNS Tunnel Server initialized")
    
    def start(self):
        """Start DNS server"""
        self.running = True
        logger.info(f"DNS Server listening on port {self.config['dns']['port']}")
        self.dns_server.start()
    
    def stop(self):
        """Stop DNS server"""
        self.running = False
        self.dns_server.stop()
        logger.info("DNS Server stopped")
    
    def register_client(self, client_id, encryption_key):
        """Register a new client"""
        self.client_keys[client_id] = encryption_key
        self.clients[client_id] = {
            'id': client_id,
            'connected': False,
            'bytes_sent': 0,
            'bytes_received': 0
        }
        logger.info(f"Client registered: {client_id}")
    
    def process_request(self, data):
        """Process tunnel request from client"""
        try:
            client_id = data.get('client_id')
            encrypted_payload = data.get('payload')
            
            if not client_id or client_id not in self.client_keys:
                return {'error': 'Invalid client'}
            
            # Decrypt payload
            key = self.client_keys[client_id]
            aesgcm = AESGCM(key)
            
            payload_bytes = base64.b64decode(encrypted_payload)
            nonce = payload_bytes[:12]
            ciphertext = payload_bytes[12:]
            
            plaintext = aesgcm.decrypt(nonce, ciphertext, None)
            request_data = json.loads(plaintext)
            
            # Update client stats
            if client_id in self.clients:
                self.clients[client_id]['connected'] = True
                self.clients[client_id]['bytes_received'] += len(payload_bytes)
            
            # Process the actual request
            response_data = self._handle_proxy_request(request_data)
            
            # Encrypt response
            response_json = json.dumps(response_data)
            nonce = os.urandom(12)
            ciphertext = aesgcm.encrypt(nonce, response_json.encode(), None)
            encrypted_response = base64.b64encode(nonce + ciphertext).decode()
            
            # Update stats
            if client_id in self.clients:
                self.clients[client_id]['bytes_sent'] += len(encrypted_response)
            
            return {
                'client_id': client_id,
                'payload': encrypted_response
            }
            
        except Exception as e:
            logger.error(f"Request processing error: {e}")
            return {'error': str(e)}
    
    def _handle_proxy_request(self, request_data):
        """Handle proxied HTTP request"""
        try:
            url = request_data.get('url')
            method = request_data.get('method', 'GET')
            headers = request_data.get('headers', {})
            body = request_data.get('body')
            
            # Make the request
            response = requests.request(
                method=method,
                url=url,
                headers=headers,
                data=body,
                timeout=10,
                allow_redirects=True
            )
            
            return {
                'status_code': response.status_code,
                'headers': dict(response.headers),
                'body': base64.b64encode(response.content).decode()
            }
            
        except Exception as e:
            logger.error(f"Proxy request error: {e}")
            return {
                'error': str(e),
                'status_code': 500
            }
    
    def get_client_stats(self):
        """Get statistics for all clients"""
        return self.clients
    
    def remove_client(self, client_id):
        """Remove a client"""
        if client_id in self.clients:
            del self.clients[client_id]
        if client_id in self.client_keys:
            del self.client_keys[client_id]
        logger.info(f"Client removed: {client_id}")
