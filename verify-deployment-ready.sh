#!/bin/bash

# Pre-Deployment Verification Script for NGINX Load Balancer on uswix864
# This script verifies that all components are ready for deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TARGET_SERVER="uswix864"
TARGET_USER="KOCETV6"
WORKING_DIR="/opt/ocp-nginx-lb"

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
        CHECK)
            echo -e "${BLUE}[CHECK]${NC} ${timestamp} - $message"
            ;;
        SUCCESS)
            echo -e "${GREEN}[✓]${NC} ${timestamp} - $message"
            ;;
        FAIL)
            echo -e "${RED}[✗]${NC} ${timestamp} - $message"
            ;;
    esac
}

# Check local files and scripts
check_local_files() {
    log CHECK "Verifying local files and scripts..."
    
    local required_files=(
        "discover-ocp-nodes.sh"
        "deploy-nginx-lb.sh"
        "deploy-to-uswix864.sh"
        "nginx-ocp-prd-lb.conf"
        "README.md"
        "DEPLOY-USWIX864.md"
    )
    
    local missing_files=()
    local executable_files=()
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            log SUCCESS "Found: $file"
            if [[ "$file" == *.sh ]]; then
                if [[ -x "$file" ]]; then
                    log SUCCESS "Executable: $file"
                else
                    log WARN "Not executable: $file"
                    executable_files+=("$file")
                fi
            fi
        else
            log FAIL "Missing: $file"
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log ERROR "Missing required files: ${missing_files[*]}"
        return 1
    fi
    
    if [[ ${#executable_files[@]} -gt 0 ]]; then
        log WARN "Making files executable: ${executable_files[*]}"
        chmod +x "${executable_files[@]}"
    fi
    
    log SUCCESS "All required files present"
    return 0
}

# Check Git repository status
check_git_status() {
    log CHECK "Checking Git repository status..."
    
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        log FAIL "Not in a Git repository"
        return 1
    fi
    
    local repo_url=$(git remote get-url origin 2>/dev/null || echo "No remote")
    log INFO "Repository remote: $repo_url"
    
    if git diff-index --quiet HEAD --; then
        log SUCCESS "Working tree is clean"
    else
        log WARN "Working tree has uncommitted changes"
        git status --porcelain
    fi
    
    local branch=$(git branch --show-current)
    log INFO "Current branch: $branch"
    
    local commits=$(git rev-list --count HEAD)
    log INFO "Total commits: $commits"
    
    log SUCCESS "Git repository status checked"
    return 0
}

# Check server connectivity
check_server_connectivity() {
    log CHECK "Checking connectivity to $TARGET_SERVER..."
    
    # Test ping
    if ping -c 1 -W 5 "$TARGET_SERVER" &>/dev/null; then
        log SUCCESS "Server $TARGET_SERVER is reachable (ping)"
    else
        log FAIL "Server $TARGET_SERVER is not reachable (ping)"
        return 1
    fi
    
    # Test SSH connectivity
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$TARGET_USER@$TARGET_SERVER" "exit" 2>/dev/null; then
        log SUCCESS "SSH connection to $TARGET_USER@$TARGET_SERVER successful"
    else
        log FAIL "SSH connection to $TARGET_USER@$TARGET_SERVER failed"
        log INFO "Please ensure SSH key authentication is set up:"
        log INFO "  ssh-copy-id $TARGET_USER@$TARGET_SERVER"
        return 1
    fi
    
    log SUCCESS "Server connectivity verified"
    return 0
}

# Check OpenShift CLI and authentication
check_openshift_cli() {
    log CHECK "Checking OpenShift CLI and authentication..."
    
    if ! command -v oc &> /dev/null; then
        log FAIL "OpenShift CLI (oc) not found"
        log INFO "Please install OpenShift CLI"
        return 1
    fi
    
    local oc_version=$(oc version --client --short 2>/dev/null || echo "Unknown")
    log INFO "OpenShift CLI version: $oc_version"
    
    if oc whoami &>/dev/null; then
        local current_user=$(oc whoami)
        local current_server=$(oc whoami --show-server)
        log SUCCESS "Authenticated as: $current_user"
        log INFO "OpenShift server: $current_server"
        
        # Check if we can access nodes
        if oc get nodes &>/dev/null; then
            local node_count=$(oc get nodes --no-headers | wc -l)
            log SUCCESS "Can access OpenShift nodes (count: $node_count)"
        else
            log FAIL "Cannot access OpenShift nodes"
            return 1
        fi
    else
        log FAIL "Not authenticated to OpenShift"
        log INFO "Please run: oc login https://api.ocp-prd.kohlerco.com:6443"
        return 1
    fi
    
    log SUCCESS "OpenShift CLI ready"
    return 0
}

# Check script configurations
check_script_configs() {
    log CHECK "Checking script configurations..."
    
    # Check discover-ocp-nodes.sh configuration
    if grep -q "OCP_CLUSTER_NAME=\"ocp-prd\"" discover-ocp-nodes.sh && \
       grep -q "API_VIP=\"10.20.136.49\"" discover-ocp-nodes.sh && \
       grep -q "INGRESS_VIP=\"10.20.136.50\"" discover-ocp-nodes.sh; then
        log SUCCESS "discover-ocp-nodes.sh configuration correct"
    else
        log FAIL "discover-ocp-nodes.sh configuration incorrect"
        return 1
    fi
    
    # Check deploy-to-uswix864.sh configuration
    if grep -q "TARGET_SERVER=\"uswix864\"" deploy-to-uswix864.sh && \
       grep -q "TARGET_USER=\"KOCETV6\"" deploy-to-uswix864.sh; then
        log SUCCESS "deploy-to-uswix864.sh configuration correct"
    else
        log FAIL "deploy-to-uswix864.sh configuration incorrect"
        return 1
    fi
    
    log SUCCESS "Script configurations verified"
    return 0
}

# Check system prerequisites
check_prerequisites() {
    log CHECK "Checking system prerequisites..."
    
    # Check jq
    if command -v jq &> /dev/null; then
        log SUCCESS "jq is installed: $(jq --version)"
    else
        log FAIL "jq is not installed"
        log INFO "Please install jq: yum install jq"
        return 1
    fi
    
    # Check git
    if command -v git &> /dev/null; then
        log SUCCESS "git is installed: $(git --version)"
    else
        log FAIL "git is not installed"
        return 1
    fi
    
    # Check ssh
    if command -v ssh &> /dev/null; then
        log SUCCESS "ssh is available"
    else
        log FAIL "ssh is not available"
        return 1
    fi
    
    log SUCCESS "System prerequisites verified"
    return 0
}

# Test server prerequisites remotely
test_server_prerequisites() {
    log CHECK "Testing server prerequisites on $TARGET_SERVER..."
    
    # Create test script
    local test_script='
        echo "=== Server Prerequisites Check ==="
        echo "Date: $(date)"
        echo "User: $(whoami)"
        echo "Hostname: $(hostname)"
        echo
        
        # Check if running as root or can sudo
        if [[ $EUID -eq 0 ]]; then
            echo "✓ Running as root"
        elif sudo -n true 2>/dev/null; then
            echo "✓ Can use sudo"
        else
            echo "✗ No root access and cannot sudo"
            exit 1
        fi
        
        # Check OS
        if [[ -f /etc/redhat-release ]]; then
            echo "✓ OS: $(cat /etc/redhat-release)"
        else
            echo "✗ Not a RHEL/CentOS system"
            exit 1
        fi
        
        # Check if can install packages
        if command -v yum &> /dev/null; then
            echo "✓ Package manager: yum available"
        else
            echo "✗ yum not available"
            exit 1
        fi
        
        # Check network connectivity
        if ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
            echo "✓ Network connectivity: OK"
        else
            echo "✗ Network connectivity: Failed"
            exit 1
        fi
        
        # Check disk space
        local disk_usage=$(df / | tail -1 | awk "{print \$5}" | sed "s/%//")
        if [[ $disk_usage -lt 80 ]]; then
            echo "✓ Disk space: ${disk_usage}% used"
        else
            echo "✗ Disk space: ${disk_usage}% used (too high)"
            exit 1
        fi
        
        echo "✓ Server prerequisites check passed"
    '
    
    if ssh "$TARGET_USER@$TARGET_SERVER" "$test_script" 2>/dev/null; then
        log SUCCESS "Server prerequisites verified on $TARGET_SERVER"
    else
        log FAIL "Server prerequisites check failed on $TARGET_SERVER"
        return 1
    fi
    
    return 0
}

# Generate deployment checklist
generate_deployment_checklist() {
    log CHECK "Generating deployment checklist..."
    
    cat > "PRE-DEPLOYMENT-CHECKLIST.md" << 'EOF'
# Pre-Deployment Checklist for NGINX Load Balancer on uswix864

## ✅ Prerequisites Verified

### Local Environment
- [ ] All required files present
- [ ] Scripts are executable
- [ ] Git repository is clean
- [ ] OpenShift CLI authenticated
- [ ] SSH key authentication set up

### Target Server (uswix864)
- [ ] Server is reachable via ping
- [ ] SSH connection successful
- [ ] Root/sudo access available
- [ ] RHEL/CentOS system
- [ ] Package manager (yum) available
- [ ] Network connectivity OK
- [ ] Sufficient disk space

### OpenShift Cluster
- [ ] OpenShift CLI authenticated
- [ ] Can access cluster nodes
- [ ] Cluster: ocp-prd.kohlerco.com
- [ ] API VIP: 10.20.136.49
- [ ] Ingress VIP: 10.20.136.50

## 🚀 Deployment Commands

### Option 1: Automated Deployment (Recommended)
```bash
# From local machine
./deploy-to-uswix864.sh deploy
```

### Option 2: Manual Deployment
```bash
# Clone repository on uswix864
ssh KOCETV6@uswix864
git clone https://github.com/rich-p-ai/nginx.git
cd nginx

# Authenticate to OpenShift
oc login https://api.ocp-prd.kohlerco.com:6443

# Run deployment
./discover-ocp-nodes.sh
./deploy-nginx-lb.sh install
```

## 🔍 Verification Commands

### After Deployment
```bash
# Check NGINX status
systemctl status nginx

# Test configuration
nginx -t

# Check health endpoints
curl http://uswix864:8080/health
curl -k https://api.ocp-prd.kohlerco.com/healthz
```

## 📋 Next Steps After Deployment

1. **Replace SSL certificates** with proper certificates
2. **Configure DNS** entries to point to uswix864
3. **Set up monitoring** and alerting
4. **Configure firewall** rules if needed
5. **Test application** access through load balancer

## 🆘 Support Information

- **Server**: uswix864
- **User**: KOCETV6
- **Working Directory**: /opt/ocp-nginx-lb
- **Repository**: https://github.com/rich-p-ai/nginx.git
- **OpenShift API**: https://api.ocp-prd.kohlerco.com:6443
EOF
    
    log SUCCESS "Deployment checklist generated: PRE-DEPLOYMENT-CHECKLIST.md"
}

# Display deployment summary
show_deployment_summary() {
    log INFO "=== NGINX Load Balancer Deployment Summary ==="
    echo ""
    echo "🎯 Target Server: $TARGET_USER@$TARGET_SERVER"
    echo "📁 Working Directory: $WORKING_DIR"
    echo "🌐 OpenShift Cluster: ocp-prd.kohlerco.com"
    echo "🔗 Repository: https://github.com/rich-p-ai/nginx.git"
    echo ""
    echo "📋 Ready for Deployment:"
    echo "  ✓ All scripts configured for KOCETV6@uswix864"
    echo "  ✓ OpenShift configuration for ocp-prd cluster"
    echo "  ✓ Load balancer configuration for API and applications"
    echo "  ✓ Automated deployment scripts available"
    echo ""
    echo "🚀 Next Steps:"
    echo "  1. Run: ./deploy-to-uswix864.sh deploy"
    echo "  2. Or follow manual deployment in PRE-DEPLOYMENT-CHECKLIST.md"
    echo ""
    echo "🔧 Quick Commands:"
    echo "  • Test connectivity: ./deploy-to-uswix864.sh check"
    echo "  • Deploy everything: ./deploy-to-uswix864.sh deploy"
    echo "  • Transfer files only: ./deploy-to-uswix864.sh transfer"
}

# Main execution
main() {
    log INFO "Starting pre-deployment verification for NGINX Load Balancer..."
    
    local checks_passed=0
    local checks_total=0
    
    # Run all checks
    local checks=(
        "check_local_files"
        "check_git_status"
        "check_prerequisites"
        "check_script_configs"
        "check_openshift_cli"
        "check_server_connectivity"
        "test_server_prerequisites"
    )
    
    for check in "${checks[@]}"; do
        ((checks_total++))
        if $check; then
            ((checks_passed++))
        fi
        echo ""
    done
    
    # Generate checklist
    generate_deployment_checklist
    
    # Show summary
    show_deployment_summary
    
    # Final status
    if [[ $checks_passed -eq $checks_total ]]; then
        log SUCCESS "All checks passed ($checks_passed/$checks_total) - Ready for deployment!"
        echo ""
        echo "🎉 You can now start the deployment with:"
        echo "   ./deploy-to-uswix864.sh deploy"
        return 0
    else
        log ERROR "Some checks failed ($checks_passed/$checks_total) - Please fix issues before deployment"
        return 1
    fi
}

# Check if running from correct directory
if [[ ! -f "discover-ocp-nodes.sh" ]]; then
    log ERROR "This script must be run from the nginx directory"
    exit 1
fi

# Run main function
main "$@"
