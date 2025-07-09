# NGINX Load Balancer Deployment Summary for uswix864

## 📋 Overview
This deployment sets up NGINX as a load balancer on server `uswix864` for the OpenShift OCP-PRD cluster environment.

## 🎯 Deployment Options

### Option 1: Automated Deployment (Recommended)
```bash
# From your local machine (Windows with bash)
./deploy-to-uswix864.sh deploy

# Or using PowerShell
.\deploy-to-uswix864.ps1 -Action deploy
```

### Option 2: Manual Deployment
Follow the step-by-step guide in `DEPLOY-USWIX864.md`

## 🚀 Quick Start Commands

### 1. Deploy from Local Machine
```bash
# Check connectivity first
./deploy-to-uswix864.sh check

# Deploy everything
./deploy-to-uswix864.sh deploy

# Or just transfer files
./deploy-to-uswix864.sh transfer
```

### 2. Connect to uswix864
```bash
ssh root@uswix864
cd /opt/ocp-nginx-lb
```

### 3. Run on uswix864
```bash
# Authenticate to OpenShift
oc login https://api.ocp-prd.kohlerco.com:6443

# Discover nodes
./discover-ocp-nodes.sh

# Deploy NGINX
./deploy-nginx-lb.sh install

# Start service
systemctl start nginx
systemctl enable nginx
```

## 📁 Files Created on uswix864

### Working Directory: `/opt/ocp-nginx-lb/`
- `discover-ocp-nodes.sh` - Node discovery script
- `deploy-nginx-lb.sh` - NGINX deployment script
- `nginx-ocp-prd-lb.conf` - Main NGINX configuration
- `DEPLOY-USWIX864.md` - Detailed deployment guide
- `QUICK-SETUP.md` - Quick reference guide
- `README-nginx-lb.md` - Complete documentation

### Generated Files (after running scripts):
- `ocp-prd-inventory.json` - Node inventory
- `ocp-prd-nginx-upstream.conf` - NGINX upstream configuration
- `ocp-prd-nodes.txt` - Simple node list

### NGINX Configuration: `/etc/nginx/`
- `nginx.conf` - Main NGINX configuration
- `conf.d/ocp-prd-nginx-upstream.conf` - Upstream servers
- `ssl/` - SSL certificates directory

## 🔧 Key Configuration Details

### Load Balancer Architecture
- **API Server**: uswix864:6443 → Master nodes:6443
- **HTTP Apps**: uswix864:80 → Worker nodes:80
- **HTTPS Apps**: uswix864:443 → Worker nodes:443
- **Health Check**: uswix864:8080 → All nodes:10256

### Network Configuration
- **API VIP**: 10.20.136.49
- **Ingress VIP**: 10.20.136.50
- **Cluster Network**: 10.20.136.0/24
- **Domain**: kohlerco.com

### Required Ports
- **80** - HTTP traffic
- **443** - HTTPS traffic
- **6443** - OpenShift API
- **8080** - Health monitoring

## 🔒 SSL Certificate Requirements

### Certificates Needed:
1. **API Server**: `api.ocp-prd.kohlerco.com`
2. **Applications**: `*.apps.ocp-prd.kohlerco.com` (wildcard)

### Certificate Locations:
```bash
/etc/nginx/ssl/ocp-prd-api.crt
/etc/nginx/ssl/ocp-prd-api.key
/etc/nginx/ssl/wildcard-apps-ocp-prd.crt
/etc/nginx/ssl/wildcard-apps-ocp-prd.key
```

## 🔍 Verification Steps

### 1. Service Status
```bash
systemctl status nginx
netstat -tlnp | grep nginx
```

### 2. Configuration Test
```bash
nginx -t
```

### 3. Endpoint Testing
```bash
# Health check
curl http://uswix864:8080/health

# API endpoint
curl -k https://api.ocp-prd.kohlerco.com/healthz

# Application endpoint
curl -k https://console-openshift-console.apps.ocp-prd.kohlerco.com
```

## 🛠️ Troubleshooting

### Common Issues:
1. **SSH Connection Failed**: Set up SSH key authentication
2. **NGINX Won't Start**: Check configuration with `nginx -t`
3. **SSL Errors**: Verify certificate paths and permissions
4. **502 Bad Gateway**: Check OpenShift node connectivity

### Debug Commands:
```bash
# Check logs
tail -f /var/log/nginx/error.log

# Test node connectivity
./discover-ocp-nodes.sh

# Check firewall
firewall-cmd --list-ports

# Check SELinux
setsebool -P httpd_can_network_connect 1
```

## 📈 Monitoring and Maintenance

### Health Endpoints:
- `http://uswix864:8080/health` - NGINX health
- `http://uswix864:8080/nginx-status` - NGINX statistics
- `https://api.ocp-prd.kohlerco.com/healthz` - API health

### Automated Updates:
```bash
# Set up cron for node discovery
crontab -e
# Add: 0 */6 * * * /opt/ocp-nginx-lb/discover-ocp-nodes.sh && /opt/ocp-nginx-lb/deploy-nginx-lb.sh reload
```

### Log Management:
```bash
# Monitor access logs
tail -f /var/log/nginx/access.log

# Monitor error logs
tail -f /var/log/nginx/error.log
```

## 📞 Support Information

### For Issues:
1. Check `/var/log/nginx/error.log`
2. Verify OpenShift connectivity: `oc get nodes`
3. Test configuration: `nginx -t`
4. Review deployment guide: `DEPLOY-USWIX864.md`

### Key Commands Reference:
```bash
# Node discovery
./discover-ocp-nodes.sh

# NGINX operations
./deploy-nginx-lb.sh install|start|stop|restart|reload|status

# Configuration test
nginx -t

# Service management
systemctl start|stop|restart|status nginx
```

## 🎯 Success Criteria

### Deployment is successful when:
- [ ] All files transferred to uswix864
- [ ] NGINX installed and configured
- [ ] OpenShift nodes discovered
- [ ] SSL certificates installed
- [ ] NGINX configuration passes test (`nginx -t`)
- [ ] NGINX service starts successfully
- [ ] Health endpoints respond
- [ ] API and application traffic routes correctly
- [ ] Monitoring and logging operational

### Post-Deployment Tasks:
1. Replace self-signed certificates with proper SSL certificates
2. Configure DNS entries to point to uswix864
3. Set up monitoring and alerting
4. Configure automated node discovery updates
5. Test failover scenarios

---

**Next Steps**: Run the deployment script and follow the verification steps to ensure successful deployment.
