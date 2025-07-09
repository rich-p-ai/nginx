# OpenShift Node Discovery Script for NGINX Load Balancer Configuration (PowerShell)
# This script discovers OpenShift nodes and generates NGINX upstream configuration
# Author: Generated for OCP-PRD environment
# Date: $(Get-Date)

param(
    [string]$OutputPath = ".",
    [switch]$Verbose,
    [switch]$Force
)

# Configuration
$OCP_CLUSTER_NAME = "ocp-prd"
$OCP_DOMAIN = "kohlerco.com"
$API_VIP = "10.20.136.49"
$INGRESS_VIP = "10.20.136.50"
$NETWORK_CIDR = "10.20.136.0/24"

# Output files
$INVENTORY_FILE = Join-Path $OutputPath "ocp-prd-inventory.json"
$NGINX_CONFIG_FILE = Join-Path $OutputPath "ocp-prd-nginx-upstream.conf"
$NODES_LIST_FILE = Join-Path $OutputPath "ocp-prd-nodes.txt"

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
        "DEBUG" { 
            if ($Verbose) {
                Write-Host "[$Level] $timestamp - $Message" -ForegroundColor Blue
            }
        }
    }
}

# Function to check if oc command is available
function Test-OCCommand {
    try {
        $null = Get-Command oc -ErrorAction Stop
        Write-ColoredOutput "OpenShift CLI (oc) found" "INFO"
        
        # Check if logged in
        $whoami = oc whoami 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColoredOutput "Authenticated as: $whoami" "INFO"
            return $true
        } else {
            Write-ColoredOutput "Not logged into OpenShift. Please run 'oc login' first." "ERROR"
            return $false
        }
    }
    catch {
        Write-ColoredOutput "OpenShift CLI (oc) not found. Please install and configure it." "ERROR"
        return $false
    }
}

# Function to get node information
function Get-NodeInformation {
    Write-ColoredOutput "Discovering OpenShift nodes..." "INFO"
    
    try {
        # Get all nodes as JSON
        $nodesJson = oc get nodes -o json | ConvertFrom-Json
        
        $nodes = @()
        foreach ($node in $nodesJson.items) {
            # Extract roles
            $roles = @()
            foreach ($label in $node.metadata.labels.PSObject.Properties) {
                if ($label.Name -match "^node-role\.kubernetes\.io/(.+)") {
                    $roles += $matches[1]
                }
            }
            
            # Get IP addresses
            $internalIP = ($node.status.addresses | Where-Object { $_.type -eq "InternalIP" }).address
            $externalIP = ($node.status.addresses | Where-Object { $_.type -eq "ExternalIP" }).address
            if (-not $externalIP) { $externalIP = "N/A" }
            
            # Get ready status
            $readyCondition = $node.status.conditions | Where-Object { $_.type -eq "Ready" }
            $ready = $readyCondition.status
            
            $nodeInfo = [PSCustomObject]@{
                name = $node.metadata.name
                roles = $roles
                internal_ip = $internalIP
                external_ip = $externalIP
                ready = $ready
                version = $node.status.nodeInfo.kubeletVersion
                arch = $node.status.nodeInfo.architecture
                os = $node.status.nodeInfo.operatingSystem
            }
            
            $nodes += $nodeInfo
        }
        
        Write-ColoredOutput "Found $($nodes.Count) nodes" "INFO"
        return $nodes
    }
    catch {
        Write-ColoredOutput "Failed to get node information: $_" "ERROR"
        return $null
    }
}

# Function to categorize nodes
function Split-NodesByRole {
    param([object[]]$Nodes)
    
    Write-ColoredOutput "Categorizing nodes by role..." "INFO"
    
    $masterNodes = $Nodes | Where-Object { $_.roles -contains "master" }
    $workerNodes = $Nodes | Where-Object { $_.roles -contains "worker" }
    
    Write-ColoredOutput "Master nodes: $($masterNodes.Count)" "INFO"
    Write-ColoredOutput "Worker nodes: $($workerNodes.Count)" "INFO"
    
    return @{
        Masters = $masterNodes
        Workers = $workerNodes
    }
}

# Function to generate inventory
function New-Inventory {
    param(
        [object[]]$AllNodes,
        [object[]]$MasterNodes,
        [object[]]$WorkerNodes
    )
    
    Write-ColoredOutput "Generating inventory file..." "INFO"
    
    $inventory = [PSCustomObject]@{
        cluster_info = [PSCustomObject]@{
            name = $OCP_CLUSTER_NAME
            domain = $OCP_DOMAIN
            api_vip = $API_VIP
            ingress_vip = $INGRESS_VIP
            network_cidr = $NETWORK_CIDR
            discovery_timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        master_nodes = $MasterNodes
        worker_nodes = $WorkerNodes
        all_nodes = $AllNodes
    }
    
    $inventory | ConvertTo-Json -Depth 10 | Out-File -FilePath $INVENTORY_FILE -Encoding UTF8
    Write-ColoredOutput "Inventory saved to $INVENTORY_FILE" "INFO"
}

# Function to generate NGINX configuration
function New-NGINXConfig {
    param(
        [object[]]$MasterNodes,
        [object[]]$WorkerNodes,
        [object[]]$AllNodes
    )
    
    Write-ColoredOutput "Generating NGINX upstream configuration..." "INFO"
    
    $config = @"
# NGINX Upstream Configuration for OpenShift OCP-PRD Cluster
# Generated automatically - do not edit manually
# Last updated: $(Get-Date)

# Upstream for OpenShift API Server (port 6443)
upstream ocp_api_servers {
    least_conn;
    
"@

    # Add master nodes for API server
    foreach ($node in $MasterNodes) {
        $config += "    server $($node.internal_ip):6443 max_fails=3 fail_timeout=30s;`n"
    }
    
    $config += @"
}

# Upstream for OpenShift Router/Ingress (HTTP - port 80)
upstream ocp_router_http {
    least_conn;
    
"@

    # Add worker nodes for HTTP traffic
    foreach ($node in $WorkerNodes) {
        $config += "    server $($node.internal_ip):80 max_fails=3 fail_timeout=30s;`n"
    }
    
    $config += @"
}

# Upstream for OpenShift Router/Ingress (HTTPS - port 443)
upstream ocp_router_https {
    least_conn;
    
"@

    # Add worker nodes for HTTPS traffic
    foreach ($node in $WorkerNodes) {
        $config += "    server $($node.internal_ip):443 max_fails=3 fail_timeout=30s;`n"
    }
    
    $config += @"
}

# Health check upstream for monitoring
upstream ocp_health_check {
    least_conn;
    
"@

    # Add all nodes for health checks
    foreach ($node in $AllNodes) {
        $config += "    server $($node.internal_ip):10256 max_fails=3 fail_timeout=30s;`n"
    }
    
    $config += @"
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
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
        
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
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
    }
}

# Application Router Load Balancer (HTTP)
server {
    listen 80;
    server_name *.apps.ocp-prd.kohlerco.com;
    
    location / {
        proxy_pass http://ocp_router_http;
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
    }
}
"@
    
    $config | Out-File -FilePath $NGINX_CONFIG_FILE -Encoding UTF8
    Write-ColoredOutput "NGINX configuration saved to $NGINX_CONFIG_FILE" "INFO"
}

# Function to generate simple nodes list
function New-NodesList {
    param(
        [object[]]$MasterNodes,
        [object[]]$WorkerNodes
    )
    
    Write-ColoredOutput "Generating simple nodes list..." "INFO"
    
    $nodesList = @"
# OpenShift OCP-PRD Nodes List
# Generated: $(Get-Date)

# Master Nodes (Control Plane)
"@

    foreach ($node in $MasterNodes) {
        $nodesList += "# $($node.name) - $($node.internal_ip) - Ready: $($node.ready)`n"
    }
    
    $nodesList += @"

# Worker Nodes (Compute)
"@

    foreach ($node in $WorkerNodes) {
        $nodesList += "# $($node.name) - $($node.internal_ip) - Ready: $($node.ready)`n"
    }
    
    $nodesList += @"

# All Node IPs (for quick reference)
Master IPs:
"@

    foreach ($node in $MasterNodes) {
        $nodesList += "$($node.internal_ip)`n"
    }
    
    $nodesList += @"

Worker IPs:
"@

    foreach ($node in $WorkerNodes) {
        $nodesList += "$($node.internal_ip)`n"
    }
    
    $nodesList | Out-File -FilePath $NODES_LIST_FILE -Encoding UTF8
    Write-ColoredOutput "Nodes list saved to $NODES_LIST_FILE" "INFO"
}

# Function to display summary
function Show-Summary {
    param(
        [object[]]$AllNodes,
        [object[]]$MasterNodes,
        [object[]]$WorkerNodes
    )
    
    Write-ColoredOutput "=== OpenShift Node Discovery Summary ===" "INFO"
    
    Write-Host "Cluster: $OCP_CLUSTER_NAME.$OCP_DOMAIN"
    Write-Host "API VIP: $API_VIP"
    Write-Host "Ingress VIP: $INGRESS_VIP"
    Write-Host "Total Nodes: $($AllNodes.Count)"
    Write-Host "Master Nodes: $($MasterNodes.Count)"
    Write-Host "Worker Nodes: $($WorkerNodes.Count)"
    Write-Host ""
    Write-Host "Generated Files:"
    Write-Host "  - $INVENTORY_FILE (JSON inventory)"
    Write-Host "  - $NGINX_CONFIG_FILE (NGINX upstream config)"
    Write-Host "  - $NODES_LIST_FILE (Simple nodes list)"
    Write-Host ""
    
    # Check node health
    $unhealthyNodes = $AllNodes | Where-Object { $_.ready -ne "True" }
    if ($unhealthyNodes.Count -gt 0) {
        Write-ColoredOutput "Unhealthy nodes detected:" "WARN"
        foreach ($node in $unhealthyNodes) {
            Write-Host "  - $($node.name) - $($node.ready)"
        }
    } else {
        Write-ColoredOutput "All nodes are healthy" "INFO"
    }
}

# Main execution
function Main {
    Write-ColoredOutput "Starting OpenShift node discovery for OCP-PRD..." "INFO"
    
    # Check prerequisites
    if (-not (Test-OCCommand)) {
        exit 1
    }
    
    # Create output directory if it doesn't exist
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    # Discover nodes
    $allNodes = Get-NodeInformation
    if (-not $allNodes) {
        exit 1
    }
    
    # Categorize nodes
    $categorizedNodes = Split-NodesByRole -Nodes $allNodes
    $masterNodes = $categorizedNodes.Masters
    $workerNodes = $categorizedNodes.Workers
    
    # Generate output files
    New-Inventory -AllNodes $allNodes -MasterNodes $masterNodes -WorkerNodes $workerNodes
    New-NGINXConfig -MasterNodes $masterNodes -WorkerNodes $workerNodes -AllNodes $allNodes
    New-NodesList -MasterNodes $masterNodes -WorkerNodes $workerNodes
    
    # Display summary
    Show-Summary -AllNodes $allNodes -MasterNodes $masterNodes -WorkerNodes $workerNodes
    
    Write-ColoredOutput "Node discovery completed successfully!" "INFO"
}

# Run the main function
Main
