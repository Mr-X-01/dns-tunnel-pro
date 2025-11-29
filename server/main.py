#!/usr/bin/env python3
"""
DNS Tunnel Pro - Main Server
Copyright (c) 2025 Mr-X-01
"""

import os
import sys
import threading
import logging
from pathlib import Path

# Add server directory to path
sys.path.insert(0, str(Path(__file__).parent))

from dns_server.server import DNSTunnelServer
from web_panel.app import create_app
from config.config_loader import load_config

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/server.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)


def main():
    """Main entry point"""
    logger.info("=" * 60)
    logger.info("DNS Tunnel Pro Server Starting...")
    logger.info("=" * 60)
    
    # Load configuration
    config = load_config()
    
    # Create necessary directories
    os.makedirs('logs', exist_ok=True)
    os.makedirs('database', exist_ok=True)
    os.makedirs('../client_configs', exist_ok=True)
    
    # Initialize DNS server
    logger.info("Initializing DNS Tunnel Server...")
    dns_server = DNSTunnelServer(config)
    
    # Start DNS server in background thread
    dns_thread = threading.Thread(target=dns_server.start, daemon=True)
    dns_thread.start()
    logger.info(f"✓ DNS Server started on port {config['dns']['port']}")
    
    # Start web panel
    logger.info("Initializing Web Panel...")
    app = create_app(config, dns_server)
    
    ssl_context = (
        config['web_panel']['ssl_cert'],
        config['web_panel']['ssl_key']
    )
    
    host = config['web_panel']['host']
    port = config['web_panel']['port']
    
    logger.info(f"✓ Web Panel starting on https://{host}:{port}")
    logger.info("=" * 60)
    logger.info("Server is ready!")
    logger.info(f"Access Web Panel: https://YOUR_IP:{port}")
    logger.info("=" * 60)
    
    # Run Flask app
    app.run(
        host=host,
        port=port,
        ssl_context=ssl_context,
        debug=False,
        threaded=True
    )


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        logger.info("\nShutting down gracefully...")
        sys.exit(0)
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)
