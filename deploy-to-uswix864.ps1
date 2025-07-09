# PowerShell Deployment Script for NGINX Load Balancer on uswix864
# This script transfers files and performs initial setup on uswix864

param(
    [string]$TargetServer = "uswix864",
    [string]$TargetUser = "root",
    [string]$WorkingDir = "/opt/ocp-nginx-lb",
    [string]$Action = "deploy"
)

# Configuration
$LOCAL_DIR = $PSScriptRoot

# Function to write colored output
function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    switch ($Level) {
        "INFO" { 
            Write-Host "[$Level] $timestamp - $Message" -ForegroundColor Green
        }
        "WARN" { 
            Write-Host "[$Level] $timestamp - $Message" -ForegroundColor Yellow
        }
        "ERROR" { 
            Write-Host "[$Level] $timestamp - $Message" -ForegroundColor Red
        }
    }
}

# Function to check server connectivity
function Test-ServerConnectivity {
    Write-ColoredOutput "Checking connectivity to $TargetServer..." "INFO"
    
    # Test ping
    if (Test-Connection -ComputerName $TargetServer -Count 1 -Quiet) {
        Write-ColoredOutput "Server $TargetServer is reachable" "INFO"
    } else {
        Write-ColoredOutput "Server $TargetServer is not reachable" "ERROR"
        return $false
    }
    
    # Test SSH (basic check)
    try {
        $result = ssh -o ConnectTimeout=10 -o BatchMode=yes "$TargetUser@$TargetServer" "exit" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColoredOutput "SSH connection to $TargetServer successful" "INFO"
            return $true
        } else {
            Write-ColoredOutput "SSH connection to $TargetServer failed" "ERROR"
            Write-ColoredOutput "Please ensure SSH key authentication is set up or use: ssh-copy-id $TargetUser@$TargetServer" "INFO"
            return $false
        }
    } catch {
        Write-ColoredOutput "SSH test failed: $_" "ERROR"
        return $false
    }
}

# Function to transfer files
function Copy-FilesToServer {
    Write-ColoredOutput "Transferring files to $TargetServer..." "INFO"
    
    # List of files to transfer
    $files = @(
        "discover-ocp-nodes.sh",
        "deploy-nginx-lb.sh",
        "nginx-ocp-prd-lb.conf",
        "DEPLOY-USWIX864.md",
        "QUICK-SETUP.md",
        "README-nginx-lb.md"
    )
    
    # Create working directory on target server
    ssh "$TargetUser@$TargetServer" "mkdir -p $WorkingDir"
    
    # Transfer each file
    foreach ($file in $files) {
        $filePath = Join-Path $LOCAL_DIR $file
        if (Test-Path $filePath) {
            Write-ColoredOutput "Transferring $file..." "INFO"
            scp "$filePath" "$TargetUser@$TargetServer`:$WorkingDir/"
        } else {
            Write-ColoredOutput "File $file not found in $LOCAL_DIR" "WARN"
        }
    }
    
    Write-ColoredOutput "File transfer completed" "INFO"
}

# Function to set up server
function Initialize-Server {
    Write-ColoredOutput "Setting up initial configuration on $TargetServer..." "INFO"
    
    # Create setup script content
    $setupScript = @'
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
'@
    
    # Execute setup script on target server
    $setupScript | ssh "$TargetUser@$TargetServer" "bash"
    
    Write-ColoredOutput "Initial setup completed on $TargetServer" "INFO"
}

# Function to create connection script
function New-ConnectionScript {
    Write-ColoredOutput "Creating connection script..." "INFO"
    
    $connectionScript = @"
#!/bin/bash
# Quick connection script for uswix864
echo "Connecting to $TargetServer..."
echo "Working directory: $WorkingDir"
ssh -t "$TargetUser@$TargetServer" "cd $WorkingDir && bash"
"@
    
    $connectionScriptPath = Join-Path $LOCAL_DIR "connect-uswix864.sh"
    $connectionScript | Out-File -FilePath $connectionScriptPath -Encoding ASCII
    
    Write-ColoredOutput "Connection script created: connect-uswix864.sh" "INFO"
}

# Function to show next steps
function Show-NextSteps {
    Write-ColoredOutput "=== Deployment to uswix864 Complete ===" "INFO"
    
    Write-Host ""
    Write-Host "Files transferred to: $TargetUser@$TargetServer`:$WorkingDir"
    Write-Host ""
    Write-Host "Next Steps:"
    Write-Host "1. Connect to server: ssh $TargetUser@$TargetServer"
    Write-Host "2. Navigate to working directory: cd $WorkingDir"
    Write-Host "3. Follow the deployment guide: cat DEPLOY-USWIX864.md"
    Write-Host ""
    Write-Host "Quick commands:"
    Write-Host "  # Connect to server"
    Write-Host "  ssh $TargetUser@$TargetServer"
    Write-Host ""
    Write-Host "  # On the server, run:"
    Write-Host "  cd $WorkingDir"
    Write-Host "  oc login https://api.ocp-prd.kohlerco.com:6443"
    Write-Host "  ./discover-ocp-nodes.sh"
    Write-Host "  ./deploy-nginx-lb.sh install"
    Write-Host ""
    Write-Host "For detailed instructions, see: DEPLOY-USWIX864.md"
}

# Function to show help
function Show-Help {
    Write-Host @"
NGINX Load Balancer Deployment Script for uswix864 (PowerShell)

Usage: .\deploy-to-uswix864.ps1 [Parameters]

Parameters:
    -TargetServer   Target server name (default: uswix864)
    -TargetUser     Target user (default: root)
    -WorkingDir     Working directory on target (default: /opt/ocp-nginx-lb)
    -Action         Action to perform (default: deploy)

Actions:
    deploy      - Transfer files and set up initial configuration
    transfer    - Transfer files only
    setup       - Run initial setup on target server
    connect     - Create connection script
    check       - Check server connectivity
    help        - Show this help message

Examples:
    .\deploy-to-uswix864.ps1 -Action deploy
    .\deploy-to-uswix864.ps1 -Action transfer
    .\deploy-to-uswix864.ps1 -Action check

Configuration:
    Target Server: $TargetServer
    Target User: $TargetUser
    Working Directory: $WorkingDir
"@
}

# Main execution
function Main {
    switch ($Action.ToLower()) {
        "deploy" {
            if (Test-ServerConnectivity) {
                Copy-FilesToServer
                Initialize-Server
                New-ConnectionScript
                Show-NextSteps
            } else {
                exit 1
            }
        }
        "transfer" {
            if (Test-ServerConnectivity) {
                Copy-FilesToServer
            } else {
                exit 1
            }
        }
        "setup" {
            if (Test-ServerConnectivity) {
                Initialize-Server
            } else {
                exit 1
            }
        }
        "connect" {
            New-ConnectionScript
        }
        "check" {
            Test-ServerConnectivity
        }
        "help" {
            Show-Help
        }
        default {
            Write-ColoredOutput "Unknown action: $Action" "ERROR"
            Show-Help
            exit 1
        }
    }
}

# Check if required files exist
if (-not (Test-Path (Join-Path $LOCAL_DIR "discover-ocp-nodes.sh"))) {
    Write-ColoredOutput "This script must be run from the directory containing the deployment files" "ERROR"
    exit 1
}

# Run main function
Main
