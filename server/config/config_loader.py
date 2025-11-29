"""Configuration loader for DNS Tunnel Pro"""

import os
import yaml
from pathlib import Path


def load_config(config_path=None):
    """Load configuration from YAML file"""
    if config_path is None:
        config_path = Path(__file__).parent / 'settings.yml'
    
    # Default configuration
    default_config = {
        'dns': {
            'port': 53,
            'domain': 'tunnel.example.com',
            'doh_resolver': 'https://common.dot.dns.yandex.net/dns-query',
            'buffer_size': 512
        },
        'web_panel': {
            'host': '0.0.0.0',
            'port': 8443,
            'ssl_cert': 'ssl/cert.pem',
            'ssl_key': 'ssl/key.pem',
            'secret_key': 'change-me-in-production',
            'admin_user': 'admin',
            'admin_password': 'admin123'
        },
        'proxy': {
            'socks5_host': '127.0.0.1',
            'socks5_port': 1080
        },
        'logging': {
            'level': 'INFO',
            'file': 'logs/server.log',
            'max_bytes': 10485760,
            'backup_count': 5
        },
        'security': {
            'encryption': 'aes-256-gcm',
            'max_clients': 100,
            'rate_limit': 1000
        }
    }
    
    # Load from file if exists
    if os.path.exists(config_path):
        with open(config_path, 'r') as f:
            loaded_config = yaml.safe_load(f)
            if loaded_config:
                default_config.update(loaded_config)
    
    # Override with environment variables
    if os.getenv('DNS_DOMAIN'):
        default_config['dns']['domain'] = os.getenv('DNS_DOMAIN')
    if os.getenv('ADMIN_PASSWORD'):
        default_config['web_panel']['admin_password'] = os.getenv('ADMIN_PASSWORD')
    if os.getenv('DOH_RESOLVER'):
        default_config['dns']['doh_resolver'] = os.getenv('DOH_RESOLVER')
    
    return default_config
