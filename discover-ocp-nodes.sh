#!/bin/bash

# OpenShift Node Discovery Script for NGINX Load Balancer Configuration
# This script discovers OpenShift nodes and generates NGINX upstream configuration
# Author: Generated for OCP-PRD environment
# Date: $(date)

set -euo pipefail

# Configuration
OCP_CLUSTER_NAME="ocp-prd"
OCP_DOMAIN="kohlerco.com"
API_VIP="10.20.136.49"
INGRESS_VIP="10.20.136.50"
NETWORK_CIDR="10.20.136.0/24"

# Output files
INVENTORY_FILE="ocp-prd-inventory.json"
NGINX_CONFIG_FILE="ocp-prd-nginx-upstream.conf"
NODES_LIST_FILE="ocp-prd-nodes.txt"

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

# Check if oc command is available
check_oc_command() {
    if ! command -v oc &> /dev/null; then
        log ERROR "OpenShift CLI (oc) not found. Please install and configure it."
        exit 1
    fi
    
    # Check if logged in to OpenShift
    if ! oc whoami &> /dev/null; then
        log ERROR "Not logged into OpenShift. Please run 'oc login' first."
        exit 1
    fi
    
    log INFO "OpenShift CLI is available and authenticated"
}

# Function to get node information
get_node_info() {
    log INFO "Discovering OpenShift nodes..."
    
    # Get all nodes with their roles and IPs
    local nodes_json=$(oc get nodes -o json)
    
    # Extract node information
    echo "$nodes_json" | jq -r '.items[] | {
        name: .metadata.name,
        roles: [.metadata.labels | to_entries[] | select(.key | startswith("node-role.kubernetes.io/")) | .key | split("/")[1]],
        internal_ip: (.status.addresses[] | select(.type == "InternalIP") | .address),
        external_ip: (.status.addresses[] | select(.type == "ExternalIP") | .address // "N/A"),
        ready: (.status.conditions[] | select(.type == "Ready") | .status),
        version: .status.nodeInfo.kubeletVersion,
        arch: .status.nodeInfo.architecture,
        os: .status.nodeInfo.operatingSystem
    }' > temp_nodes.json
    
    log INFO "Found $(jq length temp_nodes.json) nodes"
}

# Function to categorize nodes
categorize_nodes() {
    log INFO "Categorizing nodes by role..."
    
    # Separate master and worker nodes
    jq '[.[] | select(.roles[] == "master")]' temp_nodes.json > master_nodes.json
    jq '[.[] | select(.roles[] == "worker")]' temp_nodes.json > worker_nodes.json
    
    local master_count=$(jq length master_nodes.json)
    local worker_count=$(jq length worker_nodes.json)
    
    log INFO "Master nodes: $master_count"
    log INFO "Worker nodes: $worker_count"
}

# Function to generate inventory
generate_inventory() {
    log INFO "Generating inventory file..."
    
    cat > "$INVENTORY_FILE" << EOF
{
    "cluster_info": {
        "name": "$OCP_CLUSTER_NAME",
        "domain": "$OCP_DOMAIN",
        "api_vip": "$API_VIP",
        "ingress_vip": "$INGRESS_VIP",
        "network_cidr": "$NETWORK_CIDR",
        "discovery_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    },
    "master_nodes": $(cat master_nodes.json),
    "worker_nodes": $(cat worker_nodes.json),
    "all_nodes": $(cat temp_nodes.json)
}
EOF
    
    log INFO "Inventory saved to $INVENTORY_FILE"
}

# Function to generate NGINX upstream configuration
generate_nginx_config() {
    log INFO "Generating NGINX upstream configuration..."
    
    cat > "$NGINX_CONFIG_FILE" << 'EOF'
# NGINX Upstream Configuration for OpenShift OCP-PRD Cluster
# Generated automatically - do not edit manually
# Last updated: $(date)

# Upstream for OpenShift API Server (port 6443)
upstream ocp_api_servers {
    least_conn;
    
EOF
    
    # Add master nodes for API server
    jq -r '.[] | "    server \(.internal_ip):6443 max_fails=3 fail_timeout=30s;"' master_nodes.json >> "$NGINX_CONFIG_FILE"
    
    cat >> "$NGINX_CONFIG_FILE" << 'EOF'
}

# Upstream for OpenShift Router/Ingress (HTTP - port 80)
upstream ocp_router_http {
    least_conn;
    
EOF
    
    # Add worker nodes for HTTP traffic
    jq -r '.[] | "    server \(.internal_ip):80 max_fails=3 fail_timeout=30s;"' worker_nodes.json >> "$NGINX_CONFIG_FILE"
    
    cat >> "$NGINX_CONFIG_FILE" << 'EOF'
}

# Upstream for OpenShift Router/Ingress (HTTPS - port 443)
upstream ocp_router_https {
    least_conn;
    
EOF
    
    # Add worker nodes for HTTPS traffic
    jq -r '.[] | "    server \(.internal_ip):443 max_fails=3 fail_timeout=30s;"' worker_nodes.json >> "$NGINX_CONFIG_FILE"
    
    cat >> "$NGINX_CONFIG_FILE" << 'EOF'
}

# Health check upstream for monitoring
upstream ocp_health_check {
    least_conn;
    
EOF
    
    # Add all nodes for health checks
    jq -r '.[] | "    server \(.internal_ip):10256 max_fails=3 fail_timeout=30s;"' temp_nodes.json >> "$NGINX_CONFIG_FILE"
    
    cat >> "$NGINX_CONFIG_FILE" << 'EOF'
}

# Example server blocks for load balancing

# API Server Load Balancer
server {
    listen 6443 ssl;
    server_name api.ocp-prd.kohlerco.com;
    
    # SSL configuration (add your certificates)
    # ssl_certificate /path/to/cert.pem;
    # ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass https://ocp_api_servers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Increase timeouts for API calls
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}

# Application Router Load Balancer (HTTPS)
server {
    listen 443 ssl;
    server_name *.apps.ocp-prd.kohlerco.com;
    
    # SSL configuration
    # ssl_certificate /path/to/wildcard-cert.pem;
    # ssl_certificate_key /path/to/wildcard-key.pem;
    
    location / {
        proxy_pass https://ocp_router_https;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Application Router Load Balancer (HTTP)
server {
    listen 80;
    server_name *.apps.ocp-prd.kohlerco.com;
    
    location / {
        proxy_pass http://ocp_router_http;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
    
    log INFO "NGINX configuration saved to $NGINX_CONFIG_FILE"
}

# Function to generate simple nodes list
generate_nodes_list() {
    log INFO "Generating simple nodes list..."
    
    cat > "$NODES_LIST_FILE" << EOF
# OpenShift OCP-PRD Nodes List
# Generated: $(date)

# Master Nodes (Control Plane)
EOF
    
    jq -r '.[] | "# \(.name) - \(.internal_ip) - Ready: \(.ready)"' master_nodes.json >> "$NODES_LIST_FILE"
    
    cat >> "$NODES_LIST_FILE" << EOF

# Worker Nodes (Compute)
EOF
    
    jq -r '.[] | "# \(.name) - \(.internal_ip) - Ready: \(.ready)"' worker_nodes.json >> "$NODES_LIST_FILE"
    
    cat >> "$NODES_LIST_FILE" << EOF

# All Node IPs (for quick reference)
Master IPs:
EOF
    
    jq -r '.[] | .internal_ip' master_nodes.json >> "$NODES_LIST_FILE"
    
    cat >> "$NODES_LIST_FILE" << EOF

Worker IPs:
EOF
    
    jq -r '.[] | .internal_ip' worker_nodes.json >> "$NODES_LIST_FILE"
    
    log INFO "Nodes list saved to $NODES_LIST_FILE"
}

# Function to display summary
display_summary() {
    log INFO "=== OpenShift Node Discovery Summary ==="
    
    local master_count=$(jq length master_nodes.json)
    local worker_count=$(jq length worker_nodes.json)
    local total_count=$((master_count + worker_count))
    
    echo "Cluster: $OCP_CLUSTER_NAME.$OCP_DOMAIN"
    echo "API VIP: $API_VIP"
    echo "Ingress VIP: $INGRESS_VIP"
    echo "Total Nodes: $total_count"
    echo "Master Nodes: $master_count"
    echo "Worker Nodes: $worker_count"
    echo ""
    echo "Generated Files:"
    echo "  - $INVENTORY_FILE (JSON inventory)"
    echo "  - $NGINX_CONFIG_FILE (NGINX upstream config)"
    echo "  - $NODES_LIST_FILE (Simple nodes list)"
    echo ""
    
    # Check node health
    local unhealthy_nodes=$(jq -r '.[] | select(.ready != "True") | .name' temp_nodes.json)
    if [ -n "$unhealthy_nodes" ]; then
        log WARN "Unhealthy nodes detected:"
        echo "$unhealthy_nodes"
    else
        log INFO "All nodes are healthy"
    fi
}

# Function to cleanup temp files
cleanup() {
    log INFO "Cleaning up temporary files..."
    rm -f temp_nodes.json master_nodes.json worker_nodes.json
}

# Function to validate JSON output
validate_json() {
    if ! jq empty "$INVENTORY_FILE" 2>/dev/null; then
        log ERROR "Generated inventory file is not valid JSON"
        exit 1
    fi
    log INFO "Inventory file JSON validation passed"
}

# Main execution
main() {
    log INFO "Starting OpenShift node discovery for OCP-PRD..."
    
    # Check prerequisites
    check_oc_command
    
    # Discover and process nodes
    get_node_info
    categorize_nodes
    
    # Generate output files
    generate_inventory
    generate_nginx_config
    generate_nodes_list
    
    # Validate and display results
    validate_json
    display_summary
    
    # Cleanup
    cleanup
    
    log INFO "Node discovery completed successfully!"
}

# Trap for cleanup on exit
trap cleanup EXIT

# Check if jq is available
if ! command -v jq &> /dev/null; then
    log ERROR "jq is required but not installed. Please install jq first."
    exit 1
fi

# Run main function
main "$@"
