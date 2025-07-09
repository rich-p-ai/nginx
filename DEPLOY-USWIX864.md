# NGINX Load Balancer Deployment Guide for Server uswix864

## Pre-Deployment Checklist

### 1. Server Prerequisites
- [ ] Server uswix864 is accessible via SSH
- [ ] Root/sudo access on uswix864
- [ ] Network connectivity from uswix864 to OpenShift nodes (10.20.136.0/24)
- [ ] NGINX package available (RHEL/CentOS repository)
- [ ] Firewall rules configured for ports 80, 443, 6443, 8080

### 2. OpenShift Prerequisites
- [ ] OpenShift CLI (oc) installed on uswix864
- [ ] OpenShift cluster authentication configured
- [ ] Access to OpenShift API (https://api.ocp-prd.kohlerco.com:6443)

### 3. SSL Certificates
- [ ] SSL certificate for api.ocp-prd.kohlerco.com
- [ ] Wildcard SSL certificate for *.apps.ocp-prd.kohlerco.com
- [ ] Certificate private keys

## Step-by-Step Deployment

### Step 1: Connect to Server uswix864
```bash
ssh root@uswix864
# or
ssh your-user@uswix864
sudo -i
```

### Step 2: Install Prerequisites
```bash
# Install NGINX (RHEL/CentOS)
yum install -y nginx

# Install OpenShift CLI if not present
curl -O https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
tar -xzf openshift-client-linux.tar.gz
mv oc /usr/local/bin/
mv kubectl /usr/local/bin/
chmod +x /usr/local/bin/oc /usr/local/bin/kubectl

# Install jq for JSON processing
yum install -y jq

# Verify installations
nginx -v
oc version
jq --version
```

### Step 3: Configure Firewall
```bash
# Open required ports
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-port=6443/tcp
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload

# Verify firewall rules
firewall-cmd --list-ports
```

### Step 4: Transfer Scripts to uswix864
```bash
# From your local machine, copy the scripts to uswix864
scp discover-ocp-nodes.sh root@uswix864:/tmp/
scp deploy-nginx-lb.sh root@uswix864:/tmp/
scp nginx-ocp-prd-lb.conf root@uswix864:/tmp/
scp QUICK-SETUP.md root@uswix864:/tmp/
```

### Step 5: Set up Working Directory on uswix864
```bash
# On uswix864
mkdir -p /opt/ocp-nginx-lb
cd /opt/ocp-nginx-lb

# Move scripts to working directory
mv /tmp/discover-ocp-nodes.sh .
mv /tmp/deploy-nginx-lb.sh .
mv /tmp/nginx-ocp-prd-lb.conf .
mv /tmp/QUICK-SETUP.md .

# Make scripts executable
chmod +x discover-ocp-nodes.sh deploy-nginx-lb.sh
```

### Step 6: Configure OpenShift CLI Authentication
```bash
# On uswix864
oc login https://api.ocp-prd.kohlerco.com:6443
# Enter your credentials when prompted

# Verify connection
oc whoami
oc get nodes
```

### Step 7: Run Node Discovery
```bash
# From /opt/ocp-nginx-lb directory
./discover-ocp-nodes.sh

# Verify generated files
ls -la ocp-prd-*
cat ocp-prd-nodes.txt
```

### Step 8: Install SSL Certificates
```bash
# Create SSL directory
mkdir -p /etc/nginx/ssl
chmod 700 /etc/nginx/ssl

# Copy your SSL certificates to the server
# Method 1: Using scp from local machine
scp your-api-cert.crt root@uswix864:/etc/nginx/ssl/ocp-prd-api.crt
scp your-api-cert.key root@uswix864:/etc/nginx/ssl/ocp-prd-api.key
scp your-wildcard-cert.crt root@uswix864:/etc/nginx/ssl/wildcard-apps-ocp-prd.crt
scp your-wildcard-cert.key root@uswix864:/etc/nginx/ssl/wildcard-apps-ocp-prd.key

# Method 2: Create temporary self-signed certificates for testing
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/ocp-prd-api.key \
    -out /etc/nginx/ssl/ocp-prd-api.crt \
    -subj "/C=US/ST=WI/L=Kohler/O=Kohler Co/CN=api.ocp-prd.kohlerco.com"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/wildcard-apps-ocp-prd.key \
    -out /etc/nginx/ssl/wildcard-apps-ocp-prd.crt \
    -subj "/C=US/ST=WI/L=Kohler/O=Kohler Co/CN=*.apps.ocp-prd.kohlerco.com"

# Set proper permissions
chmod 600 /etc/nginx/ssl/*.key
chmod 644 /etc/nginx/ssl/*.crt
```

### Step 9: Deploy NGINX Configuration
```bash
# From /opt/ocp-nginx-lb directory
./deploy-nginx-lb.sh install

# Or manual deployment
cp nginx-ocp-prd-lb.conf /etc/nginx/nginx.conf
cp ocp-prd-nginx-upstream.conf /etc/nginx/conf.d/
```

### Step 10: Test and Start NGINX
```bash
# Test configuration
nginx -t

# If configuration is valid, start NGINX
systemctl start nginx
systemctl enable nginx

# Check status
systemctl status nginx
```

## Post-Deployment Verification

### 1. Check NGINX Status
```bash
systemctl status nginx
ps aux | grep nginx
netstat -tlnp | grep nginx
```

### 2. Test Load Balancer Endpoints
```bash
# Test API endpoint (from uswix864)
curl -k https://api.ocp-prd.kohlerco.com/healthz

# Test health endpoint
curl http://localhost:8080/health

# Test NGINX status
curl http://localhost:8080/nginx-status
```

### 3. Test from External Systems
```bash
# From another machine (test DNS resolution and connectivity)
nslookup api.ocp-prd.kohlerco.com
curl -k https://api.ocp-prd.kohlerco.com/healthz

# Test application access
curl -k https://console-openshift-console.apps.ocp-prd.kohlerco.com
```

### 4. Monitor Logs
```bash
# Follow access logs
tail -f /var/log/nginx/access.log

# Follow error logs
tail -f /var/log/nginx/error.log

# Check for any errors
grep -i error /var/log/nginx/error.log
```

## Network Configuration

### DNS Configuration
Ensure these DNS entries point to uswix864:
- api.ocp-prd.kohlerco.com → IP of uswix864
- *.apps.ocp-prd.kohlerco.com → IP of uswix864

### Load Balancer IP Configuration
If uswix864 needs to bind to specific VIPs:
```bash
# Add VIP to network interface (example)
ip addr add 10.20.136.49/24 dev eth0  # API VIP
ip addr add 10.20.136.50/24 dev eth0  # Ingress VIP

# Make persistent by adding to network config
# /etc/sysconfig/network-scripts/ifcfg-eth0:1 (for API VIP)
# /etc/sysconfig/network-scripts/ifcfg-eth0:2 (for Ingress VIP)
```

## Maintenance and Monitoring

### 1. Automated Node Discovery
```bash
# Set up cron job for node discovery updates
crontab -e
# Add line:
# 0 */6 * * * /opt/ocp-nginx-lb/discover-ocp-nodes.sh && /opt/ocp-nginx-lb/deploy-nginx-lb.sh reload
```

### 2. Log Rotation
```bash
# Configure log rotation
cat > /etc/logrotate.d/nginx-ocp << EOF
/var/log/nginx/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 0644 nginx nginx
    postrotate
        systemctl reload nginx
    endscript
}
EOF
```

### 3. Monitoring Script
```bash
# Create monitoring script
cat > /opt/ocp-nginx-lb/monitor-nginx.sh << 'EOF'
#!/bin/bash
echo "=== NGINX Load Balancer Status ==="
echo "Date: $(date)"
echo "Server: $(hostname)"
echo
echo "NGINX Status:"
systemctl status nginx --no-pager -l
echo
echo "Listening Ports:"
netstat -tlnp | grep nginx
echo
echo "Recent Errors:"
tail -20 /var/log/nginx/error.log
EOF

chmod +x /opt/ocp-nginx-lb/monitor-nginx.sh
```

## Troubleshooting Common Issues

### 1. NGINX Won't Start
```bash
# Check configuration syntax
nginx -t

# Check SELinux context
setsebool -P httpd_can_network_connect 1
restorecon -Rv /etc/nginx/

# Check port availability
netstat -tlnp | grep -E ':80|:443|:6443'
```

### 2. SSL Certificate Issues
```bash
# Check certificate validity
openssl x509 -in /etc/nginx/ssl/ocp-prd-api.crt -text -noout
openssl x509 -in /etc/nginx/ssl/wildcard-apps-ocp-prd.crt -text -noout

# Verify certificate and key match
openssl x509 -noout -modulus -in /etc/nginx/ssl/ocp-prd-api.crt | openssl md5
openssl rsa -noout -modulus -in /etc/nginx/ssl/ocp-prd-api.key | openssl md5
```

### 3. Connectivity Issues
```bash
# Test connectivity to OpenShift nodes
for ip in $(jq -r '.master_nodes[].internal_ip' ocp-prd-inventory.json); do
    echo "Testing $ip:6443"
    timeout 5 bash -c "</dev/tcp/$ip/6443" && echo "OK" || echo "FAILED"
done

for ip in $(jq -r '.worker_nodes[].internal_ip' ocp-prd-inventory.json); do
    echo "Testing $ip:443"
    timeout 5 bash -c "</dev/tcp/$ip/443" && echo "OK" || echo "FAILED"
done
```

## Files and Directories Summary

### Working Directory: /opt/ocp-nginx-lb/
- discover-ocp-nodes.sh
- deploy-nginx-lb.sh
- nginx-ocp-prd-lb.conf
- ocp-prd-inventory.json (generated)
- ocp-prd-nginx-upstream.conf (generated)
- ocp-prd-nodes.txt (generated)

### NGINX Configuration: /etc/nginx/
- nginx.conf (main configuration)
- conf.d/ocp-prd-nginx-upstream.conf (upstream servers)
- ssl/ (SSL certificates)

### Logs: /var/log/nginx/
- access.log
- error.log

## Support and Next Steps

1. **Immediate**: Verify all services are running and accessible
2. **Short-term**: Replace self-signed certificates with proper SSL certificates
3. **Long-term**: Set up monitoring and alerting for the load balancer
4. **Ongoing**: Regular maintenance and node discovery updates

For any issues, check the logs and verify network connectivity to the OpenShift nodes.
