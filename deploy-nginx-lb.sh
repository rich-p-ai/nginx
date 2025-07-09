#!/bin/bash

# NGINX Load Balancer Deployment Script for OpenShift OCP-PRD
# This script helps deploy and configure NGINX as a load balancer
# Author: Generated for OCP-PRD environment

set -euo pipefail

# Configuration
NGINX_CONFIG_DIR="/etc/nginx"
NGINX_SSL_DIR="/etc/nginx/ssl"
NGINX_LOG_DIR="/var/log/nginx"
BACKUP_DIR="/tmp/nginx-backup-$(date +%Y%m%d-%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)
            echo -e "${GREEN}[INFO]${NC} ${timestamp} - $message"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} ${timestamp} - $message"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} ${timestamp} - $message"
            ;;
        DEBUG)
            echo -e "${BLUE}[DEBUG]${NC} ${timestamp} - $message"
            ;;
    esac
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log ERROR "This script must be run as root"
        exit 1
    fi
}

# Function to check if NGINX is installed
check_nginx() {
    if ! command -v nginx &> /dev/null; then
        log ERROR "NGINX is not installed. Please install NGINX first."
        log INFO "On RHEL/CentOS: yum install nginx"
        log INFO "On Ubuntu/Debian: apt-get install nginx"
        exit 1
    fi
    
    local nginx_version=$(nginx -v 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
    log INFO "NGINX version: $nginx_version"
}

# Function to create backup
create_backup() {
    log INFO "Creating backup of existing NGINX configuration..."
    
    mkdir -p "$BACKUP_DIR"
    
    if [[ -d "$NGINX_CONFIG_DIR" ]]; then
        cp -r "$NGINX_CONFIG_DIR"/* "$BACKUP_DIR/"
        log INFO "Backup created at: $BACKUP_DIR"
    else
        log WARN "NGINX configuration directory not found"
    fi
}

# Function to create SSL directory
create_ssl_dir() {
    log INFO "Creating SSL certificate directory..."
    
    mkdir -p "$NGINX_SSL_DIR"
    chmod 700 "$NGINX_SSL_DIR"
    
    # Create self-signed certificates for testing (replace with real certificates)
    if [[ ! -f "$NGINX_SSL_DIR/ocp-prd-api.crt" ]]; then
        log WARN "Creating self-signed certificate for API server (replace with real certificate)"
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$NGINX_SSL_DIR/ocp-prd-api.key" \
            -out "$NGINX_SSL_DIR/ocp-prd-api.crt" \
            -subj "/C=US/ST=WI/L=Kohler/O=Kohler Co/CN=api.ocp-prd.kohlerco.com"
    fi
    
    if [[ ! -f "$NGINX_SSL_DIR/wildcard-apps-ocp-prd.crt" ]]; then
        log WARN "Creating self-signed wildcard certificate for apps (replace with real certificate)"
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$NGINX_SSL_DIR/wildcard-apps-ocp-prd.key" \
            -out "$NGINX_SSL_DIR/wildcard-apps-ocp-prd.crt" \
            -subj "/C=US/ST=WI/L=Kohler/O=Kohler Co/CN=*.apps.ocp-prd.kohlerco.com"
    fi
    
    if [[ ! -f "$NGINX_SSL_DIR/default.crt" ]]; then
        log INFO "Creating default SSL certificate"
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$NGINX_SSL_DIR/default.key" \
            -out "$NGINX_SSL_DIR/default.crt" \
            -subj "/C=US/ST=WI/L=Kohler/O=Kohler Co/CN=default"
    fi
    
    # Set proper permissions
    chmod 600 "$NGINX_SSL_DIR"/*.key
    chmod 644 "$NGINX_SSL_DIR"/*.crt
}

# Function to deploy NGINX configuration
deploy_config() {
    log INFO "Deploying NGINX configuration..."
    
    # Copy main configuration
    if [[ -f "$SCRIPT_DIR/nginx-ocp-prd-lb.conf" ]]; then
        cp "$SCRIPT_DIR/nginx-ocp-prd-lb.conf" "$NGINX_CONFIG_DIR/nginx.conf"
        log INFO "Main configuration deployed"
    else
        log ERROR "Main configuration file not found: $SCRIPT_DIR/nginx-ocp-prd-lb.conf"
        exit 1
    fi
    
    # Create conf.d directory
    mkdir -p "$NGINX_CONFIG_DIR/conf.d"
    
    # Copy upstream configuration if it exists
    if [[ -f "$SCRIPT_DIR/ocp-prd-nginx-upstream.conf" ]]; then
        cp "$SCRIPT_DIR/ocp-prd-nginx-upstream.conf" "$NGINX_CONFIG_DIR/conf.d/"
        log INFO "Upstream configuration deployed"
    else
        log WARN "Upstream configuration not found. Run discovery script first."
    fi
}

# Function to test NGINX configuration
test_config() {
    log INFO "Testing NGINX configuration..."
    
    if nginx -t; then
        log INFO "NGINX configuration test passed"
        return 0
    else
        log ERROR "NGINX configuration test failed"
        return 1
    fi
}

# Function to manage NGINX service
manage_service() {
    local action=$1
    
    case $action in
        start)
            log INFO "Starting NGINX service..."
            systemctl start nginx
            systemctl enable nginx
            ;;
        stop)
            log INFO "Stopping NGINX service..."
            systemctl stop nginx
            ;;
        restart)
            log INFO "Restarting NGINX service..."
            systemctl restart nginx
            ;;
        reload)
            log INFO "Reloading NGINX configuration..."
            systemctl reload nginx
            ;;
        status)
            systemctl status nginx
            ;;
    esac
}

# Function to create systemd service for discovery
create_discovery_service() {
    log INFO "Creating systemd service for node discovery..."
    
    cat > /etc/systemd/system/ocp-node-discovery.service << EOF
[Unit]
Description=OpenShift Node Discovery for NGINX
After=network.target

[Service]
Type=oneshot
User=root
WorkingDirectory=$SCRIPT_DIR
ExecStart=$SCRIPT_DIR/discover-ocp-nodes.sh
StandardOutput=journal
StandardError=journal
EOF

    cat > /etc/systemd/system/ocp-node-discovery.timer << EOF
[Unit]
Description=Run OpenShift Node Discovery every 6 hours
Requires=ocp-node-discovery.service

[Timer]
OnBootSec=15min
OnUnitActiveSec=6h

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable ocp-node-discovery.timer
    systemctl start ocp-node-discovery.timer
    
    log INFO "Discovery service created and enabled"
}

# Function to show status
show_status() {
    log INFO "=== NGINX Load Balancer Status ==="
    
    echo "NGINX Service Status:"
    systemctl status nginx --no-pager -l
    
    echo ""
    echo "NGINX Configuration Test:"
    nginx -t
    
    echo ""
    echo "Listening Ports:"
    netstat -tlnp | grep nginx
    
    echo ""
    echo "SSL Certificates:"
    ls -la "$NGINX_SSL_DIR"/*.crt 2>/dev/null || echo "No certificates found"
    
    echo ""
    echo "Discovery Timer Status:"
    systemctl status ocp-node-discovery.timer --no-pager -l 2>/dev/null || echo "Discovery timer not configured"
}

# Function to run node discovery
run_discovery() {
    log INFO "Running node discovery..."
    
    if [[ -f "$SCRIPT_DIR/discover-ocp-nodes.sh" ]]; then
        cd "$SCRIPT_DIR"
        ./discover-ocp-nodes.sh
        
        # Update NGINX configuration with new upstream servers
        if [[ -f "ocp-prd-nginx-upstream.conf" ]]; then
            cp "ocp-prd-nginx-upstream.conf" "$NGINX_CONFIG_DIR/conf.d/"
            log INFO "Updated upstream configuration"
            
            # Test and reload configuration
            if test_config; then
                manage_service reload
                log INFO "NGINX configuration reloaded successfully"
            else
                log ERROR "Failed to reload NGINX configuration"
            fi
        fi
    else
        log ERROR "Discovery script not found: $SCRIPT_DIR/discover-ocp-nodes.sh"
    fi
}

# Function to show help
show_help() {
    cat << EOF
NGINX Load Balancer Deployment Script for OpenShift OCP-PRD

Usage: $0 [COMMAND]

Commands:
    install     - Install and configure NGINX load balancer
    start       - Start NGINX service
    stop        - Stop NGINX service
    restart     - Restart NGINX service
    reload      - Reload NGINX configuration
    status      - Show NGINX and load balancer status
    test        - Test NGINX configuration
    backup      - Create backup of current configuration
    discovery   - Run node discovery and update configuration
    help        - Show this help message

Examples:
    $0 install      # Full installation and configuration
    $0 discovery    # Update node inventory and NGINX config
    $0 status       # Show current status
    $0 test         # Test configuration

EOF
}

# Main execution
main() {
    local command=${1:-help}
    
    case $command in
        install)
            check_root
            check_nginx
            create_backup
            create_ssl_dir
            deploy_config
            if test_config; then
                manage_service start
                create_discovery_service
                show_status
                log INFO "NGINX load balancer installation completed successfully!"
                log WARN "Don't forget to replace self-signed certificates with real ones"
            else
                log ERROR "Installation failed due to configuration errors"
                exit 1
            fi
            ;;
        start)
            check_root
            manage_service start
            ;;
        stop)
            check_root
            manage_service stop
            ;;
        restart)
            check_root
            manage_service restart
            ;;
        reload)
            check_root
            if test_config; then
                manage_service reload
            else
                log ERROR "Cannot reload due to configuration errors"
                exit 1
            fi
            ;;
        status)
            show_status
            ;;
        test)
            test_config
            ;;
        backup)
            check_root
            create_backup
            ;;
        discovery)
            run_discovery
            ;;
        help)
            show_help
            ;;
        *)
            log ERROR "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
