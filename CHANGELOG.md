# Changelog - DNS Tunnel Pro

## [1.1.0] - 2025-11-29

### 🚀 Major Improvements

#### Professional Installation System
- ✅ **Let's Encrypt Integration**: Automatic SSL certificate generation via Certbot
- ✅ **Custom Port Selection**: Web panel port customization (10000-60000 range)
- ✅ **UFW Firewall**: Automatic configuration with proper port rules
- ✅ **Domain Validation**: Input validation for domain and email
- ✅ **Password Security**: Minimum 8 characters with confirmation
- ✅ **Installation Info**: Detailed info file saved at `/opt/dns-tunnel-pro/INSTALL_INFO.txt`

#### Enhanced Security
- 🔐 **SSL Certificates**: 
  - Primary: Let's Encrypt (auto-renewal)
  - Fallback: Self-signed certificates
- 🔥 **Firewall Rules**:
  - Port 53/UDP (DNS Server)
  - Custom port/TCP (Web Panel)
  - Port 80,443/TCP (HTTPS)
  - Port 22/TCP (SSH - always open)

#### Improved Documentation
- 📚 **Professional README**: 
  - Beautiful badges and formatting
  - Mermaid architecture diagrams
  - Detailed feature tables
  - Step-by-step guides
- 📖 **Enhanced QUICKSTART**: 
  - Detailed installation steps
  - Firewall verification
  - SSL certificate info
  - Troubleshooting section

#### Configuration Updates
- ⚙️ **Dynamic Ports**: Web panel port configurable during installation
- 🔧 **Server Info**: Added server metadata to configs
- 📝 **Client Configs**: Include server domain and web panel port

### 🔧 Technical Changes

#### Installation Script (`install.sh`)
```bash
# New features:
- Domain validation function
- Email validation (RFC compliant)
- Random port generation (10000-60000)
- Port availability check
- Certbot installation
- UFW firewall setup
- Let's Encrypt certificate generation
- Auto-renewal hooks
- Professional output formatting
```

#### Firewall Configuration
```bash
# Automatically configured:
✓ Port 53/UDP   - DNS Server
✓ Port CUSTOM/TCP - Web Panel (user-selected)
✓ Port 80/TCP   - HTTP (Let's Encrypt)
✓ Port 443/TCP  - HTTPS
✓ Port 22/TCP   - SSH (important!)
```

#### SSL Certificates
- **Let's Encrypt**: Automatic generation if domain is properly configured
- **Self-signed**: Fallback if Let's Encrypt fails
- **Auto-renewal**: Certbot cron job with restart hook
- **Certificate paths**: Properly configured in settings.yml

### 📊 Statistics

- **Files Modified**: 8
- **Files Created**: 1 (CHANGELOG.md)
- **Lines Added**: ~500+
- **Features Added**: 10+
- **Security Improvements**: 5+

### 🎯 Installation Flow

```
1. User runs install.sh
   ↓
2. System validation (OS, root access)
   ↓
3. User inputs (domain, email, port, password)
   ↓
4. Dependencies installation
   ↓
5. Certbot installation
   ↓
6. UFW firewall configuration
   ↓
7. Let's Encrypt certificate generation
   ↓
8. Configuration file creation
   ↓
9. Systemd service setup
   ↓
10. Installation info saved
   ↓
11. Service start (optional)
```

### 🔍 Testing Checklist

- [ ] Domain validation works
- [ ] Email validation works
- [ ] Port selection works
- [ ] UFW rules applied correctly
- [ ] Let's Encrypt certificate obtained
- [ ] Fallback to self-signed works
- [ ] Web panel accessible on custom port
- [ ] DNS server starts correctly
- [ ] Client config includes all info
- [ ] Auto-renewal hook configured

### 📝 Known Issues

None currently identified.

### 🚀 Future Enhancements

- [ ] IPv6 support
- [ ] Multiple DoH resolvers fallback
- [ ] Advanced rate limiting
- [ ] Client connection logs
- [ ] Bandwidth monitoring
- [ ] API for automation
- [ ] Telegram notifications
- [ ] Multi-language support

### 🙏 Credits

- **Author**: Mr-X-01
- **License**: MIT
- **Repository**: https://github.com/Mr-X-01/dns-tunnel-pro

---

## [1.0.0] - 2025-11-29

### Initial Release

- DNS tunneling via DoH (Yandex DNS)
- Web panel management
- AES-256-GCM encryption
- Multi-client support
- SOCKS5 proxy
- Docker support
- Automatic installation
- Documentation
