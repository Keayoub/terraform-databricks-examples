# Deployment Scripts Summary

This directory contains helper scripts to deploy and manage Azure Databricks with Unity Catalog.

## 📁 Files Overview

### Documentation
- **README-DEPLOYMENT.md** - Complete deployment guide with troubleshooting
- **QUICKSTART.md** - 5-minute quick start guide
- **terraform.tfvars.template** - Configuration template with examples and documentation

### Scripts (in `scripts/` directory)

#### 1. Pre-Deployment Validation
- **pre-deploy.ps1** (PowerShell/Windows)
- **pre-deploy.sh** (Bash/Linux/Mac)

**Purpose:** Validates prerequisites before deployment
- Checks Azure CLI installation and authentication
- Verifies Terraform installation
- Validates Azure permissions
- Checks resource providers
- Provides configuration values

**Usage:**
```powershell
# Windows
.\scripts\pre-deploy.ps1

# Linux/Mac
bash scripts/pre-deploy.sh

# Detailed output
.\scripts\pre-deploy.ps1 -Detailed
```

#### 2. Post-Deployment Verification
- **post-deploy.ps1** (PowerShell/Windows)

**Purpose:** Verifies successful deployment and provides next steps
- Retrieves Terraform outputs
- Verifies Azure resources
- Displays Unity Catalog configuration
- Provides useful commands and documentation links

**Usage:**
```powershell
# Run verification
.\scripts\post-deploy.ps1

# Run and open workspace in browser
.\scripts\post-deploy.ps1 -OpenWorkspace
```

#### 3. Cleanup
- **cleanup.ps1** (PowerShell/Windows)

**Purpose:** Safely destroys all deployed resources
- Prompts for confirmation (requires typing "DELETE")
- Destroys all Terraform-managed resources
- Optionally cleans up Terraform state files

**Usage:**
```powershell
# Interactive cleanup (with confirmation)
.\scripts\cleanup.ps1

# Skip confirmation (dangerous!)
.\scripts\cleanup.ps1 -Force
```

## 🚀 Typical Workflow

### First-Time Deployment

```powershell
# 1. Validate prerequisites
.\scripts\pre-deploy.ps1

# 2. Configure your deployment
cp terraform.tfvars.template terraform.tfvars
# Edit terraform.tfvars with your values

# 3. Initialize Terraform
terraform init

# 4. Deploy infrastructure
$env:ARM_USE_CLI = "true"
terraform apply -auto-approve

# 5. Verify deployment
.\scripts\post-deploy.ps1
```

### Re-deployment (Updates)

```powershell
# Update configuration in terraform.tfvars

# Preview changes
$env:ARM_USE_CLI = "true"
terraform plan

# Apply changes
terraform apply
```

### Cleanup

```powershell
# Destroy all resources
.\scripts\cleanup.ps1
```

## 🔑 Key Configuration Values

Get these values from the pre-deploy script or manually:

```hcl
# From: az account show
subscription_id = "your-subscription-id"

# From: https://accounts.azuredatabricks.net/
account_id = "your-databricks-account-id"

# Your email (MUST be lowercase!)
metastore_admins = ["admin@yourdomain.onmicrosoft.com"]

# Storage names (must be globally unique)
metastore_storage_name = "dbxlhmetastore"
landing_external_location_name = "dbxlhlanding"
```

## ⚠️ Common Issues & Solutions

### Issue: Storage Account Name Already Exists
**Solution:** Add a random suffix to storage account names in terraform.tfvars

### Issue: Authentication Errors
**Solution:** Run `az login` and set `$env:ARM_USE_CLI = "true"`

### Issue: Email Case Sensitivity
**Solution:** Always use lowercase email addresses in `metastore_admins`

### Issue: Permission Denied
**Solution:** Ensure you have Contributor or Owner role on the subscription

## 📚 Additional Resources

- **Full Documentation:** See [README-DEPLOYMENT.md](README-DEPLOYMENT.md)
- **Quick Start:** See [QUICKSTART.md](QUICKSTART.md)
- **Azure Databricks Docs:** https://learn.microsoft.com/azure/databricks/
- **Unity Catalog Docs:** https://docs.databricks.com/data-governance/unity-catalog/

## 🔒 Security Notes

This deployment implements security best practices:
- No storage account keys (Azure AD authentication only)
- Managed identities for access
- Network isolation with VNet injection
- RBAC for all resources
- Compliant with Azure enterprise policies

## 💡 Tips

1. **Run pre-deploy script first** - Saves time by catching issues early
2. **Use lowercase emails** - Unity Catalog normalizes to lowercase
3. **Unique storage names** - Add suffix if needed (e.g., dbxlhmetastore001)
4. **Keep terraform.tfvars** - Don't commit to source control (contains secrets)
5. **Use tags consistently** - Helps with cost tracking and organization

## 🆘 Getting Help

If you encounter issues:
1. Check the troubleshooting section in README-DEPLOYMENT.md
2. Review script output for specific errors
3. Verify prerequisites with pre-deploy script
4. Check Azure service health for regional issues

## 📝 File Permissions (Linux/Mac)

Make scripts executable:
```bash
chmod +x scripts/pre-deploy.sh
chmod +x scripts/post-deploy.sh
chmod +x scripts/cleanup.sh
```

---

**Last Updated:** November 2025
**Terraform Version:** 1.0+
**Azure Provider Version:** 4.51.0+
**Databricks Provider Version:** 1.96.0+
