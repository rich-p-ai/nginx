# Quick Git Repository Setup and Deployment Guide

## 🚀 Setup GitHub Repository

### Option 1: Using the Setup Script (Bash)
```bash
# Run the setup script with your GitHub username
./setup-github-repo.sh --username your-github-username
```

### Option 2: Using PowerShell
```powershell
# Run the PowerShell setup script
.\setup-github-repo.ps1 -GitHubUsername your-github-username
```

### Option 3: Manual Setup
1. Go to https://github.com/new
2. Create a new repository named `ocp-prd-nginx-lb`
3. Run these commands:
```bash
git remote add origin https://github.com/your-username/ocp-prd-nginx-lb.git
git branch -M main
git push -u origin main
```

## 📥 Deploy from GitHub to uswix864

### Method 1: Clone and Run
```bash
# On uswix864
git clone https://github.com/your-username/ocp-prd-nginx-lb.git
cd ocp-prd-nginx-lb

# Authenticate to OpenShift
oc login https://api.ocp-prd.kohlerco.com:6443

# Run node discovery
./discover-ocp-nodes.sh

# Deploy NGINX
./deploy-nginx-lb.sh install
```

### Method 2: Direct Deployment from Local Machine
```bash
# From your local machine, deploy to uswix864
./deploy-to-uswix864.sh deploy
```

## 🔄 Update Process

### To update the repository:
```bash
# Make your changes
git add .
git commit -m "Update description"
git push origin main
```

### To update deployment on uswix864:
```bash
# On uswix864
cd ocp-prd-nginx-lb
git pull origin main
./discover-ocp-nodes.sh
./deploy-nginx-lb.sh reload
```

## 📋 Repository Structure After Setup

```
ocp-prd-nginx-lb/
├── README.md                          # Main documentation
├── .gitignore                         # Git ignore rules
├── VERSION                            # Version tracking
├── setup-github-repo.sh               # GitHub setup script (bash)
├── setup-github-repo.ps1              # GitHub setup script (PowerShell)
├── discover-ocp-nodes.sh              # Node discovery (Linux/Unix)
├── discover-ocp-nodes.ps1             # Node discovery (Windows)
├── deploy-nginx-lb.sh                 # NGINX deployment
├── deploy-to-uswix864.sh              # Remote deployment (bash)
├── deploy-to-uswix864.ps1             # Remote deployment (PowerShell)
├── nginx-ocp-prd-lb.conf              # NGINX configuration
├── DEPLOY-USWIX864.md                 # Detailed deployment guide
├── DEPLOYMENT-SUMMARY.md              # Quick deployment summary
├── QUICK-SETUP.md                     # Quick reference
└── README-nginx-lb.md                 # Complete documentation
```

## 🎯 Quick Commands Reference

```bash
# Setup GitHub repository
./setup-github-repo.sh --username your-github-username

# Deploy to uswix864 from local machine
./deploy-to-uswix864.sh deploy

# On uswix864 - clone and setup
git clone https://github.com/your-username/ocp-prd-nginx-lb.git
cd ocp-prd-nginx-lb
./discover-ocp-nodes.sh
./deploy-nginx-lb.sh install

# Update deployment
git pull origin main
./discover-ocp-nodes.sh
./deploy-nginx-lb.sh reload
```

## 🔒 Security Notes

- Generated files (inventory, certificates) are ignored by Git
- SSL certificates should be managed separately
- Use secure authentication methods for GitHub and OpenShift
- Regularly update node discovery to maintain current configuration
