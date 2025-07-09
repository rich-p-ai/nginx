#!/bin/bash

# Pre-Deployment Verification Script for NGINX Load Balancer on uswix864
# This script performs comprehensive checks before deployment

set -euo pipefail

# Configuration
TARGET_SERVER="uswix864"
TARGET_USER="root"
OCP_API_SERVER="https://api.ocp-prd.kohlerco.com:6443"
GITHUB_REPO="https://github.com/rich-p-ai/nginx.git"

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
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${NC} ${timestamp} - $message"
            ;;
        CHECK)
            echo -e "${BLUE}[CHECK]${NC} ${timestamp} - $message"
            ;;
    esac
}

# Function to display header
display_header() {
    echo ""
    echo "============================================================================="
    echo "          NGINX Load Balancer Pre-Deployment Verification"
    echo "          Target: $TARGET_SERVER"
    echo "          OpenShift: ocp-prd.kohlerco.com"
    echo "          Date: $(date)"
    echo "============================================================================="
    echo ""
}

# Function to check local prerequisites
check_local_prerequisites() {
    log CHECK "Checking local prerequisites..."
    
    local all_good=true
    
    # Check if we're in the nginx directory
    if [[ ! -f "discover-ocp-nodes.sh" ]] || [[ ! -f "deploy-nginx-lb.sh" ]]; then
        log ERROR "Must be run from the nginx directory containing deployment scripts"
        all_good=false
    else
        log SUCCESS "Running from correct directory"
    fi
    
    # Check if scripts are executable
    if [[ -x "discover-ocp-nodes.sh" ]] && [[ -x "deploy-nginx-lb.sh" ]] && [[ -x "deploy-to-uswix864.sh" ]]; then
        log SUCCESS "All scripts are executable"
    else
        log ERROR "Some scripts are not executable"
        all_good=false
    fi
    
    # Check Git repository status
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        if git diff-index --quiet HEAD --; then
            log SUCCESS "Git repository is clean"
        else
            log WARN "Git repository has uncommitted changes"
        fi
        
        # Check if GitHub remote is configured
        if git remote get-url origin &>/dev/null; then
            local remote_url=$(git remote get-url origin)
            if [[ "$remote_url" == *"github.com"* ]]; then
                log SUCCESS "GitHub remote configured: $remote_url"
            else
                log WARN "Remote is not GitHub: $remote_url"
            fi
        else
            log ERROR "No GitHub remote configured"
            all_good=false
        fi
    else
        log ERROR "Not in a Git repository"
        all_good=false
    fi
    
    # Check required tools
    local tools=("ssh" "scp" "git" "curl")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            log SUCCESS "$tool is available"
        else
            log ERROR "$tool is not available"
            all_good=false
        fi
    done
    
    return $all_good
}

# Function to check server connectivity
check_server_connectivity() {
    log CHECK "Checking connectivity to $TARGET_SERVER..."
    
    local all_good=true
    
    # Test ping connectivity
    if ping -c 1 "$TARGET_SERVER" &>/dev/null; then
        log SUCCESS "Server $TARGET_SERVER is reachable via ping"
    else
        log ERROR "Server $TARGET_SERVER is not reachable via ping"
        all_good=false
    fi
    
    # Test SSH connectivity
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$TARGET_USER@$TARGET_SERVER" exit 2>/dev/null; then
        log SUCCESS "SSH connection to $TARGET_SERVER successful"
    else
        log ERROR "SSH connection to $TARGET_SERVER failed"
        log INFO "Ensure SSH key authentication is set up: ssh-copy-id $TARGET_USER@$TARGET_SERVER"
        all_good=false
    fi
    
    return $all_good
}

# Function to check OpenShift connectivity
check_openshift_connectivity() {
    log CHECK "Checking OpenShift connectivity..."
    
    local all_good=true
    
    # Check if oc command is available
    if command -v oc &>/dev/null; then
        log SUCCESS "OpenShift CLI (oc) is available"
        
        # Check if authenticated
        if oc whoami &>/dev/null; then
            local current_user=$(oc whoami)
            local current_server=$(oc whoami --show-server)
            log SUCCESS "Authenticated as: $current_user"
            log SUCCESS "Connected to: $current_server"
            
            # Test basic cluster connectivity
            if oc get nodes &>/dev/null; then
                local node_count=$(oc get nodes --no-headers | wc -l)
                log SUCCESS "Can access cluster nodes (found $node_count nodes)"
            else
                log ERROR "Cannot access cluster nodes"
                all_good=false
            fi
        else
            log ERROR "Not authenticated to OpenShift"
            log INFO "Run: oc login $OCP_API_SERVER"
            all_good=false
        fi
    else
        log ERROR "OpenShift CLI (oc) not found"
        all_good=false
    fi
    
    return $all_good
}

# Function to check GitHub repository
check_github_repository() {
    log CHECK "Checking GitHub repository..."
    
    local all_good=true
    
    # Test GitHub repository accessibility
    if curl -s --head "$GITHUB_REPO" | head -n 1 | grep -q "200 OK"; then
        log SUCCESS "GitHub repository is accessible: $GITHUB_REPO"
    else
        log ERROR "GitHub repository is not accessible: $GITHUB_REPO"
        all_good=false
    fi
    
    return $all_good
}

# Function to validate configuration files
validate_configuration() {
    log CHECK "Validating configuration files..."
    
    local all_good=true
    
    # Check nginx configuration syntax (if nginx is available)
    if command -v nginx &>/dev/null; then
        if nginx -t -c nginx-ocp-prd-lb.conf 2>/dev/null; then
            log SUCCESS "NGINX configuration syntax is valid"
        else
            log WARN "NGINX configuration syntax check failed (normal if not on target server)"
        fi
    else
        log INFO "NGINX not available locally (will be checked on target server)"
    fi
    
    # Check if all required files exist
    local required_files=(
        "discover-ocp-nodes.sh"
        "deploy-nginx-lb.sh"
        "deploy-to-uswix864.sh"
        "nginx-ocp-prd-lb.conf"
        "README.md"
        "DEPLOY-USWIX864.md"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            log SUCCESS "Required file exists: $file"
        else
            log ERROR "Required file missing: $file"
            all_good=false
        fi
    done
    
    return $all_good
}

# Function to display deployment summary
display_deployment_summary() {
    log CHECK "Deployment Summary"
    
    echo ""
    echo "🎯 Deployment Details:"
    echo "   Target Server: $TARGET_SERVER"
    echo "   Target User: $TARGET_USER"
    echo "   Working Directory: /opt/ocp-nginx-lb"
    echo "   OpenShift Cluster: ocp-prd.kohlerco.com"
    echo "   API VIP: 10.20.136.49"
    echo "   Ingress VIP: 10.20.136.50"
    echo "   Network: 10.20.136.0/24"
    echo ""
    echo "📋 Deployment Steps:"
    echo "   1. Transfer files to $TARGET_SERVER"
    echo "   2. Install prerequisites (NGINX, jq, OpenShift CLI)"
    echo "   3. Configure OpenShift authentication"
    echo "   4. Run node discovery"
    echo "   5. Deploy NGINX configuration"
    echo "   6. Configure SSL certificates"
    echo "   7. Start and enable NGINX service"
    echo "   8. Verify load balancer functionality"
    echo ""
    echo "🔧 Required Ports:"
    echo "   - 80 (HTTP)"
    echo "   - 443 (HTTPS)"
    echo "   - 6443 (OpenShift API)"
    echo "   - 8080 (Health monitoring)"
    echo ""
}

# Function to display next steps
display_next_steps() {
    echo ""
    echo "🚀 Ready to Deploy! Choose your method:"
    echo ""
    echo "Method 1: Automated Deployment"
    echo "   ./deploy-to-uswix864.sh deploy"
    echo ""
    echo "Method 2: Manual Deployment"
    echo "   1. SSH to server: ssh $TARGET_USER@$TARGET_SERVER"
    echo "   2. Clone repository: git clone $GITHUB_REPO"
    echo "   3. Change directory: cd nginx"
    echo "   4. Run deployment: ./deploy-nginx-lb.sh install"
    echo ""
    echo "Method 3: Transfer files only"
    echo "   ./deploy-to-uswix864.sh transfer"
    echo ""
    echo "📚 Documentation:"
    echo "   - README.md - Main documentation"
    echo "   - DEPLOY-USWIX864.md - Detailed deployment guide"
    echo "   - DEPLOYMENT-SUMMARY.md - Quick reference"
    echo ""
}

# Function to run all checks
run_all_checks() {
    local overall_status=true
    
    display_header
    
    # Run all checks
    if ! check_local_prerequisites; then
        overall_status=false
    fi
    
    if ! check_server_connectivity; then
        overall_status=false
    fi
    
    if ! check_openshift_connectivity; then
        overall_status=false
    fi
    
    if ! check_github_repository; then
        overall_status=false
    fi
    
    if ! validate_configuration; then
        overall_status=false
    fi
    
    echo ""
    echo "============================================================================="
    
    if $overall_status; then
        log SUCCESS "All checks passed! Ready for deployment"
        display_deployment_summary
        display_next_steps
    else
        log ERROR "Some checks failed. Please resolve issues before deployment"
        echo ""
        echo "Common solutions:"
        echo "- Set up SSH key authentication: ssh-copy-id $TARGET_USER@$TARGET_SERVER"
        echo "- Authenticate to OpenShift: oc login $OCP_API_SERVER"
        echo "- Check network connectivity to $TARGET_SERVER"
        echo "- Verify GitHub repository access"
    fi
    
    echo "============================================================================="
    echo ""
    
    return $overall_status
}

# Main execution
main() {
    if run_all_checks; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"
