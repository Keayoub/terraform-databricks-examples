# Quick Start Guide

Deploy Azure Databricks with Unity Catalog in 5 minutes!

## Prerequisites Check

```powershell
# Run the pre-deployment validation
.\scripts\pre-deploy.ps1
```

## Step 1: Configure

```powershell
# Copy the template
cp terraform.tfvars.template terraform.tfvars

# Edit with your values (use lowercase email!)
# Required: subscription_id, account_id, location, metastore_admins
```

## Step 2: Deploy

```powershell
# Initialize Terraform
terraform init

# Set authentication
$env:ARM_USE_CLI = "true"

# Deploy (takes ~15-20 minutes)
terraform apply -auto-approve
```

## Step 3: Verify

```powershell
# Run post-deployment checks
.\scripts\post-deploy.ps1

# Get workspace URL
terraform output workspace_url
```

## Step 4: Access

Navigate to the workspace URL and sign in with your Azure AD credentials!

---

**Need help?** See [README-DEPLOYMENT.md](README-DEPLOYMENT.md) for detailed instructions.

**Having issues?** Check the troubleshooting section in the full README.
