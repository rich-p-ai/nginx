#!/bin/bash

# Quick Deployment Script for NGINX Load Balancer on uswix864
# This script transfers files and performs initial setup on uswix864

set -euo pipefail

# Configuration
TARGET_SERVER="uswix864"
TARGET_USER="root"
WORKING_DIR="/opt/ocp-nginx-lb"
LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
    esac
}

# Function to check if server is reachable
check_server_connectivity() {
    log INFO "Checking connectivity to $TARGET_SERVER..."
    
    if ping -c 1 "$TARGET_SERVER" &>/dev/null; then
        log INFO "Server $TARGET_SERVER is reachable"
    else
        log ERROR "Server $TARGET_SERVER is not reachable"
        exit 1
    fi
    
    # Test SSH connectivity
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$TARGET_USER@$TARGET_SERVER" exit 2>/dev/null; then
        log INFO "SSH connection to $TARGET_SERVER successful"
    else
        log ERROR "SSH connection to $TARGET_SERVER failed"
        log INFO "Please ensure SSH key authentication is set up or use: ssh-copy-id $TARGET_USER@$TARGET_SERVER"
        exit 1
    fi
}

# Function to transfer files to server
transfer_files() {
    log INFO "Transferring files to $TARGET_SERVER..."
    
    # List of files to transfer
    local files=(
        "discover-ocp-nodes.sh"
        "deploy-nginx-lb.sh"
        "nginx-ocp-prd-lb.conf"
        "DEPLOY-USWIX864.md"
        "QUICK-SETUP.md"
        "README-nginx-lb.md"
    )
    
    # Create working directory on target server
    ssh "$TARGET_USER@$TARGET_SERVER" "mkdir -p $WORKING_DIR"
    
    # Transfer each file
    for file in "${files[@]}"; do
        if [[ -f "$LOCAL_DIR/$file" ]]; then
            log INFO "Transferring $file..."
            scp "$LOCAL_DIR/$file" "$TARGET_USER@$TARGET_SERVER:$WORKING_DIR/"
        else
            log WARN "File $file not found in $LOCAL_DIR"
        fi
    done
    
    log INFO "File transfer completed"
}

# Function to set up initial configuration on target server
setup_server() {
    log INFO "Setting up initial configuration on $TARGET_SERVER..."
    
    # Create and execute setup script on target server
    ssh "$TARGET_USER@$TARGET_SERVER" << 'EOF'
        set -euo pipefail
        
        WORKING_DIR="/opt/ocp-nginx-lb"
        
        echo "=== Initial Setup on uswix864 ==="
        echo "Date: $(date)"
        echo "User: $(whoami)"
        echo "Working Directory: $WORKING_DIR"
        echo
        
        # Navigate to working directory
        cd "$WORKING_DIR"
        
        # Make scripts executable
        chmod +x discover-ocp-nodes.sh deploy-nginx-lb.sh
        
        # Check if NGINX is installed
        if command -v nginx &> /dev/null; then
            echo "✓ NGINX is installed: $(nginx -v 2>&1)"
        else
            echo "✗ NGINX is not installed"
            echo "Installing NGINX..."
            yum install -y nginx
        fi
        
        # Check if oc is installed
        if command -v oc &> /dev/null; then
            echo "✓ OpenShift CLI is installed: $(oc version --client)"
        else
            echo "✗ OpenShift CLI is not installed"
            echo "Please install OpenShift CLI manually"
        fi
        
        # Check if jq is installed
        if command -v jq &> /dev/null; then
            echo "✓ jq is installed: $(jq --version)"
        else
            echo "✗ jq is not installed"
            echo "Installing jq..."
            yum install -y jq
        fi
        
        # Check firewall status
        if systemctl is-active --quiet firewalld; then
            echo "✓ Firewall is active"
            echo "Current firewall rules:"
            firewall-cmd --list-ports
        else
            echo "✗ Firewall is not active"
        fi
        
        # Create SSL directory
        mkdir -p /etc/nginx/ssl
        chmod 700 /etc/nginx/ssl
        
        # Display setup summary
        echo
        echo "=== Setup Summary ==="
        echo "Working Directory: $WORKING_DIR"
        echo "Files:"
        ls -la "$WORKING_DIR"
        echo
        echo "Next Steps:"
        echo "1. Configure OpenShift CLI authentication: oc login https://api.ocp-prd.kohlerco.com:6443"
        echo "2. Run node discovery: ./discover-ocp-nodes.sh"
        echo "3. Install SSL certificates in /etc/nginx/ssl/"
        echo "4. Deploy NGINX: ./deploy-nginx-lb.sh install"
        echo "5. Test the configuration: nginx -t"
        echo "6. Start NGINX: systemctl start nginx"
        echo
        echo "For detailed instructions, see: DEPLOY-USWIX864.md"
        
EOF
    
    log INFO "Initial setup completed on $TARGET_SERVER"
}

# Function to create a quick connection script
create_connection_script() {
    log INFO "Creating connection script..."
    
    cat > "$LOCAL_DIR/connect-uswix864.sh" << EOF
#!/bin/bash
# Quick connection script for uswix864
echo "Connecting to $TARGET_SERVER..."
echo "Working directory: $WORKING_DIR"
ssh -t "$TARGET_USER@$TARGET_SERVER" "cd $WORKING_DIR && bash"
EOF
    
    chmod +x "$LOCAL_DIR/connect-uswix864.sh"
    log INFO "Connection script created: connect-uswix864.sh"
}

# Function to show next steps
show_next_steps() {
    log INFO "=== Deployment to uswix864 Complete ==="
    
    echo ""
    echo "Files transferred to: $TARGET_USER@$TARGET_SERVER:$WORKING_DIR"
    echo ""
    echo "Next Steps:"
    echo "1. Connect to server: ssh $TARGET_USER@$TARGET_SERVER"
    echo "2. Navigate to working directory: cd $WORKING_DIR"
    echo "3. Follow the deployment guide: cat DEPLOY-USWIX864.md"
    echo ""
    echo "Quick commands:"
    echo "  # Connect to server"
    echo "  ssh $TARGET_USER@$TARGET_SERVER"
    echo ""
    echo "  # Or use the connection script"
    echo "  ./connect-uswix864.sh"
    echo ""
    echo "  # On the server, run:"
    echo "  cd $WORKING_DIR"
    echo "  oc login https://api.ocp-prd.kohlerco.com:6443"
    echo "  ./discover-ocp-nodes.sh"
    echo "  ./deploy-nginx-lb.sh install"
    echo ""
    echo "For detailed instructions, see: DEPLOY-USWIX864.md"
}

# Function to show help
show_help() {
    cat << EOF
NGINX Load Balancer Deployment Script for uswix864

Usage: $0 [COMMAND]

Commands:
    deploy      - Transfer files and set up initial configuration (default)
    transfer    - Transfer files only
    setup       - Run initial setup on target server
    connect     - Create connection script
    check       - Check server connectivity
    help        - Show this help message

Examples:
    $0 deploy       # Full deployment
    $0 transfer     # Transfer files only
    $0 check        # Check connectivity

Configuration:
    Target Server: $TARGET_SERVER
    Target User: $TARGET_USER
    Working Directory: $WORKING_DIR

EOF
}

# Main execution
main() {
    local command=${1:-deploy}
    
    case $command in
        deploy)
            check_server_connectivity
            transfer_files
            setup_server
            create_connection_script
            show_next_steps
            ;;
        transfer)
            check_server_connectivity
            transfer_files
            ;;
        setup)
            check_server_connectivity
            setup_server
            ;;
        connect)
            create_connection_script
            ;;
        check)
            check_server_connectivity
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

# Check if running from correct directory
if [[ ! -f "discover-ocp-nodes.sh" ]]; then
    log ERROR "This script must be run from the directory containing the deployment files"
    exit 1
fi

# Run main function
main "$@"
