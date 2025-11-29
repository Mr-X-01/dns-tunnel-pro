"""Web Panel for DNS Tunnel Pro"""

import os
import secrets
import json
import base64
from datetime import datetime
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, send_file
from flask_login import LoginManager, UserMixin, login_user, logout_user, login_required, current_user
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

db = SQLAlchemy()
login_manager = LoginManager()


class User(UserMixin, db.Model):
    """User model for web panel"""
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    is_admin = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)


class Client(db.Model):
    """Client model"""
    id = db.Column(db.Integer, primary_key=True)
    client_id = db.Column(db.String(64), unique=True, nullable=False)
    name = db.Column(db.String(100), nullable=False)
    encryption_key = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_seen = db.Column(db.DateTime)
    is_active = db.Column(db.Boolean, default=True)
    bytes_sent = db.Column(db.BigInteger, default=0)
    bytes_received = db.Column(db.BigInteger, default=0)
    notes = db.Column(db.Text)


def create_app(config, dns_server):
    """Create Flask application"""
    app = Flask(__name__)
    
    # Configuration
    app.config['SECRET_KEY'] = config['web_panel']['secret_key']
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///database/tunnel.db'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    
    # Initialize extensions
    db.init_app(app)
    login_manager.init_app(app)
    login_manager.login_view = 'login'
    
    # Store DNS server reference
    app.dns_server = dns_server
    app.tunnel_config = config
    
    with app.app_context():
        db.create_all()
        
        # Create admin user if not exists
        admin = User.query.filter_by(username=config['web_panel']['admin_user']).first()
        if not admin:
            admin = User(
                username=config['web_panel']['admin_user'],
                is_admin=True
            )
            admin.set_password(config['web_panel']['admin_password'])
            db.session.add(admin)
            db.session.commit()
    
    @login_manager.user_loader
    def load_user(user_id):
        return User.query.get(int(user_id))
    
    # Routes
    @app.route('/')
    @login_required
    def index():
        """Dashboard"""
        clients = Client.query.filter_by(is_active=True).all()
        stats = dns_server.get_client_stats()
        
        # Update client stats from DNS server
        for client in clients:
            if client.client_id in stats:
                client_stats = stats[client.client_id]
                client.bytes_sent = client_stats.get('bytes_sent', 0)
                client.bytes_received = client_stats.get('bytes_received', 0)
                if client_stats.get('connected'):
                    client.last_seen = datetime.utcnow()
        
        db.session.commit()
        
        total_clients = len(clients)
        active_clients = sum(1 for c in clients if c.last_seen and 
                           (datetime.utcnow() - c.last_seen).seconds < 300)
        total_traffic = sum(c.bytes_sent + c.bytes_received for c in clients)
        
        return render_template('dashboard.html',
                             clients=clients,
                             total_clients=total_clients,
                             active_clients=active_clients,
                             total_traffic=total_traffic)
    
    @app.route('/login', methods=['GET', 'POST'])
    def login():
        """Login page"""
        if current_user.is_authenticated:
            return redirect(url_for('index'))
        
        if request.method == 'POST':
            username = request.form.get('username')
            password = request.form.get('password')
            
            user = User.query.filter_by(username=username).first()
            
            if user and user.check_password(password):
                login_user(user)
                return redirect(url_for('index'))
            else:
                flash('Invalid username or password', 'error')
        
        return render_template('login.html')
    
    @app.route('/logout')
    @login_required
    def logout():
        """Logout"""
        logout_user()
        return redirect(url_for('login'))
    
    @app.route('/clients')
    @login_required
    def clients_list():
        """List all clients"""
        clients = Client.query.all()
        return render_template('clients.html', clients=clients)
    
    @app.route('/clients/add', methods=['GET', 'POST'])
    @login_required
    def add_client():
        """Add new client"""
        if request.method == 'POST':
            name = request.form.get('name')
            notes = request.form.get('notes', '')
            
            # Generate client ID and encryption key
            client_id = secrets.token_hex(16)
            encryption_key = AESGCM.generate_key(bit_length=256)
            key_b64 = base64.b64encode(encryption_key).decode()
            
            # Create client
            client = Client(
                client_id=client_id,
                name=name,
                encryption_key=key_b64,
                notes=notes,
                is_active=True
            )
            
            db.session.add(client)
            db.session.commit()
            
            # Register with DNS server
            dns_server.register_client(client_id, encryption_key)
            
            flash(f'Client "{name}" created successfully!', 'success')
            return redirect(url_for('client_detail', client_id=client.id))
        
        return render_template('add_client.html')
    
    @app.route('/clients/<int:client_id>')
    @login_required
    def client_detail(client_id):
        """Client details"""
        client = Client.query.get_or_404(client_id)
        return render_template('client_detail.html', client=client)
    
    @app.route('/clients/<int:client_id>/config')
    @login_required
    def download_config(client_id):
        """Download client configuration"""
        client = Client.query.get_or_404(client_id)
        
        # Get server info from config
        server_domain = config.get('server', {}).get('domain', config['dns']['domain'])
        web_panel_port = config['web_panel']['port']
        
        config_data = {
            'client_id': client.client_id,
            'encryption_key': client.encryption_key,
            'dns_domain': config['dns']['domain'],
            'doh_resolver': config['dns']['doh_resolver'],
            'socks5_port': config['proxy']['socks5_port'],
            'server_info': {
                'domain': server_domain,
                'web_panel_port': web_panel_port
            }
        }
        
        # Save to temp file
        config_path = f'../client_configs/{client.client_id}.json'
        os.makedirs('../client_configs', exist_ok=True)
        
        with open(config_path, 'w') as f:
            json.dump(config_data, f, indent=2)
        
        return send_file(config_path, 
                        as_attachment=True,
                        download_name=f'{client.name.replace(" ", "_")}_config.json')
    
    @app.route('/clients/<int:client_id>/delete', methods=['POST'])
    @login_required
    def delete_client(client_id):
        """Delete client"""
        client = Client.query.get_or_404(client_id)
        
        # Remove from DNS server
        dns_server.remove_client(client.client_id)
        
        # Delete from database
        db.session.delete(client)
        db.session.commit()
        
        flash(f'Client "{client.name}" deleted successfully!', 'success')
        return redirect(url_for('clients_list'))
    
    @app.route('/clients/<int:client_id>/toggle', methods=['POST'])
    @login_required
    def toggle_client(client_id):
        """Toggle client active status"""
        client = Client.query.get_or_404(client_id)
        client.is_active = not client.is_active
        db.session.commit()
        
        status = 'enabled' if client.is_active else 'disabled'
        flash(f'Client "{client.name}" {status}!', 'success')
        return redirect(url_for('client_detail', client_id=client_id))
    
    @app.route('/settings', methods=['GET', 'POST'])
    @login_required
    def settings():
        """Settings page"""
        if request.method == 'POST':
            new_password = request.form.get('new_password')
            confirm_password = request.form.get('confirm_password')
            
            if new_password and new_password == confirm_password:
                current_user.set_password(new_password)
                db.session.commit()
                flash('Password changed successfully!', 'success')
            else:
                flash('Passwords do not match!', 'error')
        
        return render_template('settings.html')
    
    @app.route('/api/stats')
    @login_required
    def api_stats():
        """API endpoint for statistics"""
        clients = Client.query.filter_by(is_active=True).all()
        stats = dns_server.get_client_stats()
        
        return jsonify({
            'total_clients': len(clients),
            'active_clients': len([c for c in stats.values() if c.get('connected')]),
            'total_traffic': sum(c.bytes_sent + c.bytes_received for c in clients),
            'clients': [
                {
                    'id': c.client_id,
                    'name': c.name,
                    'connected': stats.get(c.client_id, {}).get('connected', False),
                    'bytes_sent': stats.get(c.client_id, {}).get('bytes_sent', 0),
                    'bytes_received': stats.get(c.client_id, {}).get('bytes_received', 0)
                }
                for c in clients
            ]
        })
    
    return app
