# OpenShift OCP-PRD NGINX Load Balancer

This repository contains scripts and configuration files for deploying NGINX as a load balancer for the OpenShift OCP-PRD cluster.

## 🎯 Quick Start

### 1. Clone this repository to your deployment server
```bash
git clone https://github.com/your-username/ocp-prd-nginx-lb.git
cd ocp-prd-nginx-lb
```

### 2. Deploy to uswix864 (from your local machine)
```bash
# Automated deployment
./deploy-to-uswix864.sh deploy

# Or using PowerShell
.\deploy-to-uswix864.ps1 -Action deploy
```

### 3. Complete setup on uswix864
```bash
# Connect to server
ssh root@uswix864
cd /opt/ocp-nginx-lb

# Authenticate to OpenShift
oc login https://api.ocp-prd.kohlerco.com:6443

# Run node discovery
./discover-ocp-nodes.sh

# Deploy NGINX
./deploy-nginx-lb.sh install
```

## 📁 Repository Structure

```
├── discover-ocp-nodes.sh              # Node discovery script (Linux/Unix)
├── discover-ocp-nodes.ps1             # Node discovery script (Windows)
├── deploy-nginx-lb.sh                 # NGINX deployment script
├── deploy-to-uswix864.sh              # Automated deployment to uswix864
├── deploy-to-uswix864.ps1             # PowerShell deployment script
├── nginx-ocp-prd-lb.conf              # Complete NGINX configuration
├── DEPLOY-USWIX864.md                 # Detailed deployment guide
├── DEPLOYMENT-SUMMARY.md              # Quick deployment summary
├── QUICK-SETUP.md                     # Quick reference guide
└── README-nginx-lb.md                 # Complete documentation
```

## 🔧 What This Does

- **Discovers OpenShift Nodes**: Automatically finds master and worker nodes
- **Generates NGINX Configuration**: Creates upstream configurations for load balancing
- **Deploys Load Balancer**: Sets up NGINX to load balance OpenShift traffic
- **Manages SSL Certificates**: Handles certificates for API and application traffic
- **Provides Monitoring**: Includes health checks and monitoring endpoints

## 🌐 Architecture

### Load Balancer Flow
- **API Traffic**: Client → NGINX (uswix864:6443) → Master Nodes (port 6443)
- **HTTP Apps**: Client → NGINX (uswix864:80) → Worker Nodes (port 80)
- **HTTPS Apps**: Client → NGINX (uswix864:443) → Worker Nodes (port 443)

### OpenShift Cluster Details
- **Cluster**: ocp-prd.kohlerco.com
- **API VIP**: 10.20.136.49
- **Ingress VIP**: 10.20.136.50
- **Network**: 10.20.136.0/24

## 🚀 Usage Examples

### Deploy from Local Machine
```bash
# Check connectivity
./deploy-to-uswix864.sh check

# Deploy everything
./deploy-to-uswix864.sh deploy

# Transfer files only
./deploy-to-uswix864.sh transfer
```

### On Target Server (uswix864)
```bash
# Node discovery
./discover-ocp-nodes.sh

# NGINX operations
./deploy-nginx-lb.sh install
./deploy-nginx-lb.sh start
./deploy-nginx-lb.sh status
./deploy-nginx-lb.sh reload
```

## 📋 Prerequisites

### Local Machine
- SSH access to uswix864
- Git for cloning this repository

### Target Server (uswix864)
- RHEL/CentOS with yum package manager
- Root/sudo access
- Network connectivity to OpenShift nodes (10.20.136.0/24)
- OpenShift CLI (oc) installed
- NGINX installed

### OpenShift Cluster
- Valid authentication credentials
- Access to API server (api.ocp-prd.kohlerco.com:6443)
- Node discovery permissions

## 🔒 SSL Certificates

You'll need SSL certificates for:
- **API Server**: api.ocp-prd.kohlerco.com
- **Applications**: *.apps.ocp-prd.kohlerco.com (wildcard)

Place certificates in `/etc/nginx/ssl/` on uswix864:
```
/etc/nginx/ssl/ocp-prd-api.crt
/etc/nginx/ssl/ocp-prd-api.key
/etc/nginx/ssl/wildcard-apps-ocp-prd.crt
/etc/nginx/ssl/wildcard-apps-ocp-prd.key
```

## 🔍 Verification

After deployment, test these endpoints:
```bash
# NGINX health
curl http://uswix864:8080/health

# API health
curl -k https://api.ocp-prd.kohlerco.com/healthz

# Application access
curl -k https://console-openshift-console.apps.ocp-prd.kohlerco.com
```

## 📊 Generated Files

The scripts generate:
- `ocp-prd-inventory.json` - Complete node inventory
- `ocp-prd-nginx-upstream.conf` - NGINX upstream configuration
- `ocp-prd-nodes.txt` - Simple node list

## 🛠️ Troubleshooting

### Common Issues
- **SSH connection failed**: Set up SSH key authentication
- **NGINX won't start**: Check configuration with `nginx -t`
- **502 Bad Gateway**: Verify OpenShift node connectivity
- **SSL errors**: Check certificate paths and permissions

### Debug Commands
```bash
# Check logs
tail -f /var/log/nginx/error.log

# Test configuration
nginx -t

# Check connectivity
./discover-ocp-nodes.sh

# Check firewall
firewall-cmd --list-ports
```

## 📈 Monitoring

### Health Endpoints
- `http://uswix864:8080/health` - NGINX health
- `http://uswix864:8080/nginx-status` - NGINX statistics
- `https://api.ocp-prd.kohlerco.com/healthz` - API health

### Automated Maintenance
Set up cron job for node discovery updates:
```bash
# Update every 6 hours
0 */6 * * * /opt/ocp-nginx-lb/discover-ocp-nodes.sh && /opt/ocp-nginx-lb/deploy-nginx-lb.sh reload
```

## 📚 Documentation

- **README-nginx-lb.md** - Complete documentation
- **DEPLOY-USWIX864.md** - Detailed deployment guide
- **DEPLOYMENT-SUMMARY.md** - Quick deployment summary
- **QUICK-SETUP.md** - Quick reference guide

## 🤝 Contributing

When updating this repository:
1. Test all scripts on a development environment first
2. Update documentation if functionality changes
3. Follow the existing code style and structure
4. Ensure all scripts are executable

## 📞 Support

For deployment issues:
1. Check the troubleshooting section
2. Review NGINX and OpenShift logs
3. Verify network connectivity
4. Test SSL certificate validity

## 🔄 Updates

To update the deployment:
1. Pull latest changes: `git pull origin main`
2. Run node discovery: `./discover-ocp-nodes.sh`
3. Reload NGINX: `./deploy-nginx-lb.sh reload`

---

**Environment**: OpenShift OCP-PRD (ocp-prd.kohlerco.com)  
**Load Balancer**: uswix864  
**Maintained by**: Kohler Co Infrastructure Team
