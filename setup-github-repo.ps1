# GitHub Repository Setup Script for OpenShift OCP-PRD NGINX Load Balancer (PowerShell)
# This script helps you set up a GitHub repository and push your code

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubUsername,
    
    [string]$RepoName = "ocp-prd-nginx-lb",
    
    [string]$Description = "OpenShift OCP-PRD NGINX Load Balancer - Automated deployment and configuration scripts"
)

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
        "STEP" { 
            Write-Host "[$Level] $timestamp - $Message" -ForegroundColor Blue
        }
    }
}

# Function to check if we're in the right directory
function Test-CorrectDirectory {
    if (-not (Test-Path "README.md") -or -not (Test-Path "discover-ocp-nodes.sh")) {
        Write-ColoredOutput "This script must be run from the nginx directory containing the deployment files" "ERROR"
        return $false
    }
    
    Write-ColoredOutput "Verified we're in the correct directory" "INFO"
    return $true
}

# Function to check git status
function Test-GitStatus {
    try {
        $null = git rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-ColoredOutput "This is not a git repository. Please run 'git init' first" "ERROR"
            return $false
        }
        
        # Check if there are uncommitted changes
        git diff-index --quiet HEAD --
        if ($LASTEXITCODE -ne 0) {
            Write-ColoredOutput "There are uncommitted changes. Please commit them first" "WARN"
            git status
            return $false
        }
        
        Write-ColoredOutput "Git repository is clean and ready" "INFO"
        return $true
    }
    catch {
        Write-ColoredOutput "Error checking git status: $_" "ERROR"
        return $false
    }
}

# Function to set up GitHub remote
function Set-GitHubRemote {
    param(
        [string]$Username,
        [string]$RepoName
    )
    
    try {
        # Check if remote already exists
        $existingRemote = git remote get-url origin 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColoredOutput "Remote 'origin' already exists: $existingRemote" "INFO"
            return $true
        }
        
        # Add GitHub remote
        $repoUrl = "https://github.com/$Username/$RepoName.git"
        git remote add origin $repoUrl
        
        Write-ColoredOutput "Added GitHub remote: $repoUrl" "INFO"
        return $true
    }
    catch {
        Write-ColoredOutput "Error setting up GitHub remote: $_" "ERROR"
        return $false
    }
}

# Function to create GitHub repository (requires GitHub CLI)
function New-GitHubRepository {
    param(
        [string]$Username,
        [string]$RepoName,
        [string]$Description
    )
    
    # Check if GitHub CLI is available
    try {
        $null = Get-Command gh -ErrorAction Stop
    }
    catch {
        Write-ColoredOutput "GitHub CLI (gh) not found. You'll need to create the repository manually" "WARN"
        Write-ColoredOutput "Go to https://github.com/new and create a repository named '$RepoName'" "INFO"
        Write-ColoredOutput "Then run this script again with your GitHub username" "INFO"
        return $false
    }
    
    # Check if already authenticated
    try {
        gh auth status 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-ColoredOutput "Please authenticate with GitHub CLI first:" "INFO"
            Write-ColoredOutput "Run: gh auth login" "INFO"
            return $false
        }
    }
    catch {
        Write-ColoredOutput "Please authenticate with GitHub CLI first: gh auth login" "INFO"
        return $false
    }
    
    # Create repository
    try {
        Write-ColoredOutput "Creating GitHub repository: $RepoName" "INFO"
        gh repo create $RepoName --description $Description --public --source=. --push
        
        Write-ColoredOutput "GitHub repository created successfully" "INFO"
        return $true
    }
    catch {
        Write-ColoredOutput "Error creating GitHub repository: $_" "ERROR"
        return $false
    }
}

# Function to push to GitHub
function Push-ToGitHub {
    try {
        Write-ColoredOutput "Pushing to GitHub..." "INFO"
        
        # Set default branch to main
        git branch -M main
        
        # Push to GitHub
        git push -u origin main
        
        Write-ColoredOutput "Successfully pushed to GitHub" "INFO"
        return $true
    }
    catch {
        Write-ColoredOutput "Error pushing to GitHub: $_" "ERROR"
        return $false
    }
}

# Function to display repository information
function Show-RepositoryInfo {
    param(
        [string]$Username,
        [string]$RepoName
    )
    
    Write-ColoredOutput "=== Repository Setup Complete ===" "INFO"
    Write-Host ""
    Write-Host "Repository: https://github.com/$Username/$RepoName"
    Write-Host "Clone URL: https://github.com/$Username/$RepoName.git"
    Write-Host ""
    Write-Host "To clone on uswix864:"
    Write-Host "  git clone https://github.com/$Username/$RepoName.git"
    Write-Host "  cd $RepoName"
    Write-Host "  ./discover-ocp-nodes.sh"
    Write-Host ""
    Write-Host "To pull updates:"
    Write-Host "  git pull origin main"
    Write-Host "  ./deploy-nginx-lb.sh reload"
    Write-Host ""
    Write-Host "Files in repository:"
    $files = git ls-files
    foreach ($file in $files) {
        Write-Host "  - $file"
    }
}

# Function to show help
function Show-Help {
    Write-Host @"
GitHub Repository Setup Script for OpenShift OCP-PRD NGINX Load Balancer (PowerShell)

Usage: .\setup-github-repo.ps1 -GitHubUsername <username> [OPTIONS]

Parameters:
    -GitHubUsername     GitHub username (required)
    -RepoName           Repository name (default: ocp-prd-nginx-lb)
    -Description        Repository description

Examples:
    .\setup-github-repo.ps1 -GitHubUsername your-github-username
    .\setup-github-repo.ps1 -GitHubUsername your-username -RepoName my-nginx-lb
    .\setup-github-repo.ps1 -GitHubUsername your-username -Description "My NGINX Load Balancer"

Prerequisites:
    - Git repository initialized and committed
    - GitHub CLI (gh) installed and authenticated (optional)
    - GitHub account and repository creation permissions

Manual Setup (if GitHub CLI not available):
    1. Go to https://github.com/new
    2. Create repository named 'ocp-prd-nginx-lb'
    3. Run: git remote add origin https://github.com/your-username/ocp-prd-nginx-lb.git
    4. Run: git push -u origin main
"@
}

# Main execution
function Main {
    Write-ColoredOutput "Starting GitHub repository setup for OpenShift OCP-PRD NGINX Load Balancer" "INFO"
    
    # Check prerequisites
    if (-not (Test-CorrectDirectory)) {
        exit 1
    }
    
    if (-not (Test-GitStatus)) {
        exit 1
    }
    
    # Set up GitHub remote
    if (-not (Set-GitHubRemote -Username $GitHubUsername -RepoName $RepoName)) {
        exit 1
    }
    
    # Try to create GitHub repository (optional)
    $repoCreated = New-GitHubRepository -Username $GitHubUsername -RepoName $RepoName -Description $Description
    if ($repoCreated) {
        Write-ColoredOutput "Repository created via GitHub CLI" "INFO"
    } else {
        Write-ColoredOutput "You may need to create the repository manually at https://github.com/new" "INFO"
        Write-ColoredOutput "Repository name: $RepoName" "INFO"
        Write-ColoredOutput "After creating the repository, run: git push -u origin main" "INFO"
    }
    
    # Push to GitHub
    if (Push-ToGitHub) {
        Show-RepositoryInfo -Username $GitHubUsername -RepoName $RepoName
    } else {
        Write-ColoredOutput "Failed to push to GitHub. Please check your credentials and try again" "ERROR"
        exit 1
    }
    
    Write-ColoredOutput "GitHub repository setup completed successfully!" "INFO"
}

# Run main function
try {
    Main
}
catch {
    Write-ColoredOutput "Script execution failed: $_" "ERROR"
    exit 1
}
