#!/bin/bash

# GitHub Repository Setup Script for OpenShift OCP-PRD NGINX Load Balancer
# This script helps you set up a GitHub repository and push your code

set -euo pipefail

# Configuration
REPO_NAME="ocp-prd-nginx-lb"
GITHUB_USERNAME=""  # You'll need to set this
REPO_DESCRIPTION="OpenShift OCP-PRD NGINX Load Balancer - Automated deployment and configuration scripts"

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
        STEP)
            echo -e "${BLUE}[STEP]${NC} ${timestamp} - $message"
            ;;
    esac
}

# Function to check if we're in the right directory
check_directory() {
    if [[ ! -f "README.md" ]] || [[ ! -f "discover-ocp-nodes.sh" ]]; then
        log ERROR "This script must be run from the nginx directory containing the deployment files"
        exit 1
    fi
    
    log INFO "Verified we're in the correct directory"
}

# Function to check git status
check_git_status() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        log ERROR "This is not a git repository. Please run 'git init' first"
        exit 1
    fi
    
    # Check if there are uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        log WARN "There are uncommitted changes. Please commit them first"
        git status
        exit 1
    fi
    
    log INFO "Git repository is clean and ready"
}

# Function to set up GitHub remote
setup_github_remote() {
    local username=$1
    local repo_name=$2
    
    # Check if remote already exists
    if git remote get-url origin &>/dev/null; then
        log INFO "Remote 'origin' already exists: $(git remote get-url origin)"
        return 0
    fi
    
    # Add GitHub remote
    local repo_url="https://github.com/$username/$repo_name.git"
    git remote add origin "$repo_url"
    
    log INFO "Added GitHub remote: $repo_url"
}

# Function to create GitHub repository (requires GitHub CLI)
create_github_repo() {
    local username=$1
    local repo_name=$2
    local description=$3
    
    if ! command -v gh &> /dev/null; then
        log WARN "GitHub CLI (gh) not found. You'll need to create the repository manually"
        log INFO "Go to https://github.com/new and create a repository named '$repo_name'"
        log INFO "Then run this script again with your GitHub username"
        return 1
    fi
    
    # Check if already authenticated
    if ! gh auth status &>/dev/null; then
        log INFO "Please authenticate with GitHub CLI first:"
        log INFO "Run: gh auth login"
        return 1
    fi
    
    # Create repository
    log INFO "Creating GitHub repository: $repo_name"
    gh repo create "$repo_name" \
        --description "$description" \
        --public \
        --source=. \
        --push
    
    log INFO "GitHub repository created successfully"
}

# Function to push to GitHub
push_to_github() {
    log INFO "Pushing to GitHub..."
    
    # Set default branch to main
    git branch -M main
    
    # Push to GitHub
    git push -u origin main
    
    log INFO "Successfully pushed to GitHub"
}

# Function to display repository information
display_repo_info() {
    local username=$1
    local repo_name=$2
    
    log INFO "=== Repository Setup Complete ==="
    echo ""
    echo "Repository: https://github.com/$username/$repo_name"
    echo "Clone URL: https://github.com/$username/$repo_name.git"
    echo ""
    echo "To clone on uswix864:"
    echo "  git clone https://github.com/$username/$repo_name.git"
    echo "  cd $repo_name"
    echo "  ./discover-ocp-nodes.sh"
    echo ""
    echo "To pull updates:"
    echo "  git pull origin main"
    echo "  ./deploy-nginx-lb.sh reload"
    echo ""
    echo "Files in repository:"
    git ls-files | sed 's/^/  - /'
}

# Function to show help
show_help() {
    cat << EOF
GitHub Repository Setup Script for OpenShift OCP-PRD NGINX Load Balancer

Usage: $0 [OPTIONS]

Options:
    -u, --username USERNAME     GitHub username (required)
    -r, --repo-name NAME        Repository name (default: $REPO_NAME)
    -d, --description DESC      Repository description
    -h, --help                  Show this help message

Examples:
    $0 --username your-github-username
    $0 -u your-username -r my-nginx-lb
    $0 --username your-username --description "My NGINX Load Balancer"

Prerequisites:
    - Git repository initialized and committed
    - GitHub CLI (gh) installed and authenticated (optional)
    - GitHub account and repository creation permissions

Manual Setup (if GitHub CLI not available):
    1. Go to https://github.com/new
    2. Create repository named '$REPO_NAME'
    3. Run: $0 --username your-github-username

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--username)
                GITHUB_USERNAME="$2"
                shift 2
                ;;
            -r|--repo-name)
                REPO_NAME="$2"
                shift 2
                ;;
            -d|--description)
                REPO_DESCRIPTION="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log ERROR "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$GITHUB_USERNAME" ]]; then
        log ERROR "GitHub username is required"
        show_help
        exit 1
    fi
}

# Main execution
main() {
    log INFO "Starting GitHub repository setup for OpenShift OCP-PRD NGINX Load Balancer"
    
    # Check prerequisites
    check_directory
    check_git_status
    
    # Set up GitHub remote
    setup_github_remote "$GITHUB_USERNAME" "$REPO_NAME"
    
    # Try to create GitHub repository (optional)
    if create_github_repo "$GITHUB_USERNAME" "$REPO_NAME" "$REPO_DESCRIPTION"; then
        log INFO "Repository created via GitHub CLI"
    else
        log INFO "You may need to create the repository manually at https://github.com/new"
        log INFO "Repository name: $REPO_NAME"
        log INFO "After creating the repository, run: git push -u origin main"
    fi
    
    # Push to GitHub
    if push_to_github; then
        display_repo_info "$GITHUB_USERNAME" "$REPO_NAME"
    else
        log ERROR "Failed to push to GitHub. Please check your credentials and try again"
        exit 1
    fi
    
    log INFO "GitHub repository setup completed successfully!"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
fi
