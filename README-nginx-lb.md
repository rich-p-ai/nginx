# OpenShift OCP-PRD NGINX Load Balancer Setup

This repository contains scripts and configuration files to automatically discover OpenShift nodes and generate NGINX load balancer configurations for the OCP-PRD cluster.

## Overview

The setup includes:
- **Node Discovery Scripts**: Automatically discover OpenShift master and worker nodes
- **NGINX Configuration Generation**: Create upstream configurations based on discovered nodes
- **Complete Load Balancer Template**: Production-ready NGINX configuration

## Files Description

### Discovery Scripts
- `discover-ocp-nodes.sh` - Bash script for Linux/Unix systems
- `discover-ocp-nodes.ps1` - PowerShell script for Windows systems

### Generated Files
- `ocp-prd-inventory.json` - Complete inventory of discovered nodes
- `ocp-prd-nginx-upstream.conf` - NGINX upstream configuration
- `ocp-prd-nodes.txt` - Simple text list of nodes and IPs

### Configuration Templates
- `nginx-ocp-prd-lb.conf` - Complete NGINX load balancer configuration

## OpenShift Cluster Information

Based on the install configuration:
- **Cluster Name**: ocp-prd
- **Domain**: kohlerco.com
- **API VIP**: 10.20.136.49
- **Ingress VIP**: 10.20.136.50
- **Network**: 10.20.136.0/24 (VLAN225)

## Prerequisites

### For Discovery Scripts
1. **OpenShift CLI (oc)** - Install and authenticate
2. **jq** (for bash script) - JSON processor
3. **PowerShell 5.1+** (for PowerShell script)

### For NGINX Load Balancer
1. **NGINX** - Version 1.16+ recommended
2. **SSL Certificates** - For API and applications
3. **Network Access** - To OpenShift nodes

## Usage

### 1. Node Discovery

#### Using Bash Script (Linux/Unix)
```bash
# Make script executable
chmod +x discover-ocp-nodes.sh

# Run the discovery
./discover-ocp-nodes.sh
```

#### Using PowerShell Script (Windows)
```powershell
# Run the discovery
.\discover-ocp-nodes.ps1

# With custom output path
.\discover-ocp-nodes.ps1 -OutputPath "C:\nginx\config"

# With verbose output
.\discover-ocp-nodes.ps1 -Verbose
```

### 2. NGINX Configuration

#### Update Upstream Servers
1. Run the discovery script to generate `ocp-prd-nginx-upstream.conf`
2. Copy the upstream configurations to your main NGINX config
3. Update SSL certificate paths in the configuration

#### Example Integration
```nginx
# Include the generated upstream configuration
include /etc/nginx/conf.d/ocp-prd-nginx-upstream.conf;

# Or copy the upstream blocks directly into your main config
```

### 3. SSL Certificate Setup

You'll need SSL certificates for:
- **API Server**: `api.ocp-prd.kohlerco.com`
- **Applications**: `*.apps.ocp-prd.kohlerco.com` (wildcard)

#### Certificate Locations (update in config)
```nginx
# API Server
ssl_certificate /etc/nginx/ssl/ocp-prd-api.crt;
ssl_certificate_key /etc/nginx/ssl/ocp-prd-api.key;

# Applications (wildcard)
ssl_certificate /etc/nginx/ssl/wildcard-apps-ocp-prd.crt;
ssl_certificate_key /etc/nginx/ssl/wildcard-apps-ocp-prd.key;
```

## Load Balancer Architecture

### Traffic Flow
1. **API Traffic** → NGINX (port 6443) → Master Nodes (port 6443)
2. **HTTP Apps** → NGINX (port 80) → Worker Nodes (port 80)
3. **HTTPS Apps** → NGINX (port 443) → Worker Nodes (port 443)

### Health Checks
- **Node Health**: Port 10256 (kubelet health)
- **NGINX Health**: Port 8080 (`/health` endpoint)
- **API Health**: `/healthz` endpoint

## Generated Output Examples

### JSON Inventory Structure
```json
{
  "cluster_info": {
    "name": "ocp-prd",
    "domain": "kohlerco.com",
    "api_vip": "10.20.136.49",
    "ingress_vip": "10.20.136.50",
    "network_cidr": "10.20.136.0/24"
  },
  "master_nodes": [...],
  "worker_nodes": [...],
  "all_nodes": [...]
}
```

### NGINX Upstream Example
```nginx
upstream ocp_api_servers {
    least_conn;
    server 10.20.136.51:6443 max_fails=3 fail_timeout=30s;
    server 10.20.136.52:6443 max_fails=3 fail_timeout=30s;
    server 10.20.136.53:6443 max_fails=3 fail_timeout=30s;
}
```

## Monitoring and Maintenance

### Health Check Endpoints
- `http://nginx-server:8080/health` - NGINX health
- `http://nginx-server:8080/nginx-status` - NGINX statistics
- `https://api.ocp-prd.kohlerco.com/healthz` - API health

### Log Files
- `/var/log/nginx/access.log` - Access logs
- `/var/log/nginx/error.log` - Error logs

### Maintenance Tasks
1. **Regular Discovery**: Run discovery script when nodes are added/removed
2. **Certificate Renewal**: Update SSL certificates before expiration
3. **Log Rotation**: Configure log rotation for NGINX logs
4. **Health Monitoring**: Set up monitoring for upstream health

## Troubleshooting

### Common Issues

#### Discovery Script Fails
```bash
# Check OpenShift authentication
oc whoami

# Check cluster connectivity
oc get nodes

# Verify jq installation (bash script)
jq --version
```

#### NGINX Configuration Issues
```bash
# Test NGINX configuration
nginx -t

# Check upstream health
curl -k https://api.ocp-prd.kohlerco.com/healthz

# Verify SSL certificates
openssl x509 -in /etc/nginx/ssl/ocp-prd-api.crt -text -noout
```

#### Load Balancer Issues
1. **503 Errors**: Check if upstream servers are healthy
2. **SSL Issues**: Verify certificate paths and validity
3. **Connection Timeouts**: Adjust proxy timeouts
4. **WebSocket Issues**: Ensure upgrade headers are set

### Log Analysis
```bash
# Check for upstream errors
grep "upstream" /var/log/nginx/error.log

# Monitor access patterns
tail -f /var/log/nginx/access.log

# Check for SSL errors
grep "SSL" /var/log/nginx/error.log
```

## Security Considerations

1. **SSL/TLS**: Use strong cipher suites and protocols
2. **Network**: Restrict access to management ports
3. **Certificates**: Use proper certificate validation
4. **Headers**: Set appropriate security headers
5. **Monitoring**: Enable comprehensive logging

## Automation

### Scheduled Discovery
Set up a cron job to periodically update node inventory:
```bash
# Run discovery every 6 hours
0 */6 * * * /path/to/discover-ocp-nodes.sh > /var/log/ocp-discovery.log 2>&1
```

### Configuration Management
Consider using configuration management tools like Ansible or Puppet to:
- Deploy NGINX configurations
- Manage SSL certificates
- Update upstream servers
- Monitor health

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review NGINX and OpenShift logs
3. Verify network connectivity
4. Test SSL certificate validity

## License

This configuration is provided as-is for the OCP-PRD environment at Kohler Co.
