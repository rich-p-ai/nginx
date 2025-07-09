# NGINX Load Balancer for OpenShift OCP-PRD

**Status:** ✅ DEPLOYED AND OPERATIONAL  
**Version:** 1.1.0  
**Server:** uswix864  
**Date:** July 9, 2025

## 🎉 Deployment Complete!

This repository contains the NGINX load balancer configuration for the OpenShift OCP-PRD cluster. The deployment has been **successfully completed** and is currently operational on server uswix864.

### 🏆 What's Deployed:
- **NGINX Load Balancer** replacing HAProxy
- **SSL Termination** for secure connections
- **Multi-node Load Balancing** across 8 OpenShift nodes
- **Health Monitoring** endpoints
- **Production-ready Configuration**

## 🌐 Current Configuration

### **Load Balancer Endpoints:**
- **API Server:** `https://api.ocp-prd.kohlerco.com:6443` → Master nodes
- **HTTP Applications:** `http://*.apps.ocp-prd.kohlerco.com:80` → Worker + Infra nodes
- **HTTPS Applications:** `https://*.apps.ocp-prd.kohlerco.com:443` → Worker + Infra nodes
- **Health Check:** `http://uswix864:8080/ping` → Load balancer status
- **Statistics:** `http://uswix864:8080/nginx-status` → NGINX metrics

### **OpenShift Nodes:**
```
Master Nodes (API Load Balancing):
├── ocp-prd-jmq98-master-0 → 10.20.136.15
├── ocp-prd-jmq98-master-1 → 10.20.136.25
└── ocp-prd-jmq98-master-2 → 10.20.136.16

Worker Nodes (Application Load Balancing):
├── ocp-prd-jmq98-worker-0-pk46v → 10.20.136.63
├── ocp-prd-jmq98-worker-0-vrx59 → 10.20.136.64
└── ocp-prd-jmq98-worker-0-zj7kv → 10.20.136.62

Infrastructure Nodes (Application Load Balancing):
├── ocp-prd-jmq98-infra-odf-0-qshwc → 10.20.136.67
├── ocp-prd-jmq98-infra-odf-0-vw296 → 10.20.136.66
└── ocp-prd-jmq98-infra-odf-0-zzl92 → 10.20.136.65
```

## 📁 Repository Files

This clean, production-ready repository contains:

```
├── deploy-nginx-lb.sh                 # Main deployment and management script
├── discover-ocp-nodes.sh              # Node discovery script (Linux/Unix)
├── discover-ocp-nodes.ps1             # Node discovery script (Windows)
├── nginx-ocp-prd-lb.conf              # Complete NGINX configuration
├── DEPLOY-USWIX864.md                 # Detailed deployment guide
├── DEPLOYMENT-SUCCESS.md              # Deployment completion summary
├── QUICK-SETUP.md                     # Quick reference guide
├── README.md                          # This documentation
└── VERSION                            # Version tracking
```

## 🔧 Management Commands

### **On uswix864 server:**
```bash
# Check status
./deploy-nginx-lb.sh status

# Restart NGINX
./deploy-nginx-lb.sh restart

# Reload configuration
./deploy-nginx-lb.sh reload

# Stop/Start services
./deploy-nginx-lb.sh stop
./deploy-nginx-lb.sh start
```

### **Node Discovery (if needed):**
```bash
# Rediscover OpenShift nodes
./discover-ocp-nodes.sh

# Check generated upstream configuration
cat /etc/nginx/conf.d/ocp-prd-nginx-upstream.conf
```

## 🔍 Health Monitoring

### **Health Check Endpoints:**
```bash
# NGINX health
curl http://uswix864:8080/ping

# NGINX statistics
curl http://uswix864:8080/nginx-status

# OpenShift API health
curl -k https://localhost:6443/healthz
```

### **Log Monitoring:**
```bash
# Watch access logs
tail -f /var/log/nginx/access.log

# Watch error logs
tail -f /var/log/nginx/error.log

# Check for errors
grep -i error /var/log/nginx/error.log
```

## 🔒 SSL Configuration

Current SSL setup:
- **API Certificate:** `/etc/nginx/ssl/ocp-prd-api.crt` (self-signed)
- **Apps Certificate:** `/etc/nginx/ssl/wildcard-apps-ocp-prd.crt` (self-signed)

### **To Replace with Production Certificates:**
```bash
# Replace API certificate
sudo cp your-api-cert.crt /etc/nginx/ssl/ocp-prd-api.crt
sudo cp your-api-cert.key /etc/nginx/ssl/ocp-prd-api.key

# Replace apps certificate
sudo cp your-wildcard-cert.crt /etc/nginx/ssl/wildcard-apps-ocp-prd.crt
sudo cp your-wildcard-cert.key /etc/nginx/ssl/wildcard-apps-ocp-prd.key

# Set proper permissions
sudo chmod 644 /etc/nginx/ssl/*.crt
sudo chmod 600 /etc/nginx/ssl/*.key

# Reload NGINX
sudo ./deploy-nginx-lb.sh reload
```

## 🛠️ Troubleshooting

### **Common Commands:**
```bash
# Test NGINX configuration
nginx -t

# Check what's listening on ports
netstat -tlnp | grep nginx

# Check NGINX processes
ps aux | grep nginx

# Restart if needed
systemctl restart nginx
```

### **Configuration Files:**
- **Main Config:** `/etc/nginx/nginx.conf`
- **Upstream Config:** `/etc/nginx/conf.d/ocp-prd-nginx-upstream.conf`
- **SSL Certificates:** `/etc/nginx/ssl/`

## 📊 Deployment History

- **v1.0.0:** Initial repository setup and scripts
- **v1.1.0:** ✅ **DEPLOYED** - NGINX load balancer operational on uswix864

## 🔄 Updates

To update the configuration:
1. Pull latest changes from this repository
2. Run node discovery if nodes have changed
3. Reload NGINX configuration
4. Verify health endpoints

## 📞 Support

For issues or questions:
1. Check the health monitoring endpoints
2. Review NGINX logs
3. Verify OpenShift node connectivity
4. Ensure SSL certificates are valid

---

**Environment:** OpenShift OCP-PRD (ocp-prd.kohlerco.com)  
**Load Balancer:** uswix864  
**Repository:** https://github.com/rich-p-ai/nginx.git  
**Status:** ✅ PRODUCTION READY
