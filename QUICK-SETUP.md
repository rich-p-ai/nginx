# Quick Setup Guide for NGINX Load Balancer

## Prerequisites Checklist

- [ ] OpenShift CLI (oc) installed and authenticated
- [ ] NGINX installed on the load balancer server
- [ ] SSL certificates for api.ocp-prd.kohlerco.com and *.apps.ocp-prd.kohlerco.com
- [ ] Network connectivity from load balancer to OpenShift nodes
- [ ] Root access on the load balancer server

## Quick Setup Steps

### 1. Authenticate to OpenShift
```bash
oc login https://api.ocp-prd.kohlerco.com:6443
```

### 2. Discover OpenShift Nodes
```bash
# Linux/Unix
./discover-ocp-nodes.sh

# Windows
.\discover-ocp-nodes.ps1
```

### 3. Deploy NGINX Configuration
```bash
# Full deployment (Linux/Unix)
sudo ./deploy-nginx-lb.sh install

# Or manual deployment
sudo cp nginx-ocp-prd-lb.conf /etc/nginx/nginx.conf
sudo cp ocp-prd-nginx-upstream.conf /etc/nginx/conf.d/
```

### 4. Install SSL Certificates
```bash
# Copy your certificates to /etc/nginx/ssl/
sudo cp your-api-cert.crt /etc/nginx/ssl/ocp-prd-api.crt
sudo cp your-api-cert.key /etc/nginx/ssl/ocp-prd-api.key
sudo cp your-wildcard-cert.crt /etc/nginx/ssl/wildcard-apps-ocp-prd.crt
sudo cp your-wildcard-cert.key /etc/nginx/ssl/wildcard-apps-ocp-prd.key
```

### 5. Test and Start
```bash
# Test configuration
sudo nginx -t

# Start NGINX
sudo systemctl start nginx
sudo systemctl enable nginx
```

## Verification

### Check NGINX Status
```bash
sudo systemctl status nginx
```

### Test Load Balancer
```bash
# Test API endpoint
curl -k https://api.ocp-prd.kohlerco.com/healthz

# Test applications endpoint
curl -k https://console-openshift-console.apps.ocp-prd.kohlerco.com
```

### Monitor Logs
```bash
# Follow access logs
sudo tail -f /var/log/nginx/access.log

# Follow error logs
sudo tail -f /var/log/nginx/error.log
```

## Troubleshooting

### Common Issues
1. **503 Service Unavailable** - Check if OpenShift nodes are accessible
2. **SSL Certificate errors** - Verify certificate paths and validity
3. **Connection refused** - Check firewall rules and port availability
4. **DNS resolution** - Ensure proper DNS configuration

### Health Checks
```bash
# Check NGINX health
curl http://load-balancer-ip:8080/health

# Check upstream health
curl -k https://api.ocp-prd.kohlerco.com/healthz
```

## Maintenance

### Update Node Inventory
```bash
# Run discovery script when nodes change
./discover-ocp-nodes.sh
sudo ./deploy-nginx-lb.sh reload
```

### Certificate Renewal
```bash
# Replace certificates and reload
sudo ./deploy-nginx-lb.sh reload
```

## Files Overview

- `discover-ocp-nodes.sh` - Node discovery (Linux/Unix)
- `discover-ocp-nodes.ps1` - Node discovery (Windows)
- `deploy-nginx-lb.sh` - NGINX deployment script
- `nginx-ocp-prd-lb.conf` - Main NGINX configuration
- `ocp-prd-nginx-upstream.conf` - Generated upstream configuration
- `ocp-prd-inventory.json` - Node inventory (generated)
- `ocp-prd-nodes.txt` - Simple node list (generated)

## Support

For issues:
1. Check logs in `/var/log/nginx/`
2. Verify OpenShift connectivity: `oc get nodes`
3. Test NGINX configuration: `nginx -t`
4. Check firewall rules and network connectivity
