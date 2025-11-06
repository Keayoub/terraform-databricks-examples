# Azure Databricks Lakehouse with Unity Catalog - Deployment Guide

This guide will help you deploy a complete Azure Databricks workspace with Unity Catalog from scratch.

## 📋 Prerequisites

Before you begin, ensure you have:

1. **Azure CLI** installed and authenticated
2. **Terraform** v1.0+ installed
3. **Azure Subscription** with appropriate permissions:
   - Contributor or Owner access
   - Ability to create resource groups, storage accounts, and Databricks workspaces
4. **Databricks Account** ID (Premium or Enterprise tier required for Unity Catalog)
5. **PowerShell** (for Windows) or Bash (for Linux/Mac)

## 🚀 Quick Start

### Step 1: Prepare Your Environment

Run the pre-deployment script to verify prerequisites and gather required information:

```powershell
# Windows/PowerShell
.\scripts\pre-deploy.ps1

# Linux/Mac
bash scripts/pre-deploy.sh
```

This script will:
- Verify Azure CLI authentication
- Display your subscription ID
- Check for required permissions
- Verify Terraform installation

### Step 2: Configure Variables

Copy the template and fill in your values:

```powershell
cp terraform.tfvars.template terraform.tfvars
```

Edit `terraform.tfvars` with your specific values:

```hcl
# Required: Your Azure subscription ID
subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Required: Your Databricks Account ID (get from https://accounts.azuredatabricks.net)
account_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Required: Azure region for deployment
location = "eastus2"

# Required: Your email (use lowercase!)
metastore_admins = ["admin@yourdomain.onmicrosoft.com"]

# Storage account names (must be globally unique, lowercase, no hyphens)
metastore_storage_name = "dbxlhmetastore"
landing_external_location_name = "dbxlhlanding"

# Resource names
shared_resource_group_name = "rg-databricks-shared"
metastore_name = "unity-catalog-metastore"
access_connector_name = "dbx-lh-connector"

# Workspace configuration
workspace_name = "dbx-lakehouse-workspace"
spoke_vnet_address_space = "10.178.0.0/16"

# Tags
tags = {
  Environment = "dev"
  Project     = "databricks-lakehouse"
  Owner       = "admin@yourdomain.onmicrosoft.com"
}
```

**Important Notes:**
- Use **lowercase** email addresses in `metastore_admins`
- Storage account names must be **lowercase alphanumeric** (no hyphens or special characters)
- Storage account names must be **globally unique** across all Azure subscriptions

### Step 3: Initialize Terraform

```powershell
terraform init
```

This downloads required providers:
- `azurerm` v4.51.0+ (Azure Resource Manager)
- `databricks` v1.96.0+ (Databricks)

### Step 4: Validate Configuration

```powershell
terraform validate
```

### Step 5: Preview Deployment

```powershell
# Set environment variable for Azure AD authentication
$env:ARM_USE_CLI = "true"

# Generate and review the plan
terraform plan
```

Review the plan to ensure:
- Approximately 31 resources will be created
- Storage accounts have `shared_access_key_enabled = false`
- Network configuration matches your requirements

### Step 6: Deploy

```powershell
# Deploy all resources
$env:ARM_USE_CLI = "true"
terraform apply -auto-approve
```

**Deployment Timeline:**
- Storage accounts: ~2-3 minutes each
- Networking resources: ~1-2 minutes
- **Databricks workspace: ~4-5 minutes** (longest step)
- Unity Catalog setup: ~1-2 minutes
- Grants: ~20-30 seconds

**Total deployment time: ~15-20 minutes**

### Step 7: Verify Deployment

After successful deployment, Terraform will output:

```
Outputs:

azure_resource_group_id = "/subscriptions/.../resourceGroups/adb-xxxxx-rg"
workspace_id = "4323989595923028"
workspace_url = "https://adb-4323989595923028.8.azuredatabricks.net"
```

## 📦 What Gets Deployed

### Core Infrastructure

1. **Resource Groups**
   - Workspace resource group (dynamically named)
   - Shared resource group (for storage and access connector)

2. **Networking**
   - Virtual Network (10.178.0.0/16)
   - Public subnet with Databricks delegation
   - Private subnet with Databricks delegation
   - Network Security Group with Databricks rules
   - NAT Gateway for outbound connectivity
   - Public IP for NAT Gateway

3. **Storage Accounts** (with Azure AD authentication only)
   - Unity Catalog metastore storage (ADLS Gen2)
   - Landing zone external location storage (ADLS Gen2)
   - Both configured with:
     - `shared_access_key_enabled = false` (complies with security policies)
     - `public_network_access_enabled = false` (restricted access)
     - Hierarchical namespace enabled

4. **Azure Databricks Workspace**
   - Premium tier with Unity Catalog support
   - VNet injection enabled
   - Managed resource group
   - Public endpoint (can be configured for private endpoints)

5. **Unity Catalog Components**
   - Metastore with Azure AD managed identity
   - Access Connector with system-assigned identity
   - Metastore assignment to workspace
   - External location (landing)
   - Catalog (bronze_catalog_dev)
   - Schema (bronze_source1)

6. **IAM & RBAC**
   - Storage Blob Data Contributor (for access connector)
   - Storage Queue Data Contributor (for access connector)
   - EventGrid EventSubscription Contributor (for access connector)
   - Unity Catalog grants for admin users
   - **Note:** The access connector's managed identity is automatically registered with Unity Catalog via the `databricks_metastore_data_access` resource

## 🔒 Security Features

This deployment implements Azure security best practices:

- ✅ **No storage account keys** - Uses Azure AD authentication exclusively
- ✅ **Managed identities** - Access connector uses system-assigned identity
- ✅ **Network isolation** - VNet injection with private subnets
- ✅ **RBAC** - Role-based access control for all resources
- ✅ **Encrypted storage** - Storage accounts encrypted at rest
- ✅ **Private endpoints ready** - Can be extended for fully private deployment

## 🛠️ Troubleshooting

### Issue: Storage Account Name Already Exists

**Error:** `StorageAccountAlreadyExists`

**Solution:** Storage account names must be globally unique. Update your `terraform.tfvars`:

```hcl
metastore_storage_name = "dbxlhmetastore${random_suffix}"
landing_external_location_name = "dbxlhlanding${random_suffix}"
```

### Issue: Azure Policy Blocking Deployment

**Error:** `RequestDisallowedByPolicy` or `This request is not authorized`

**Solution:** Your Azure subscription may have policies restricting:
- Storage accounts with key-based authentication
- Public network access

This deployment is already configured to comply with these policies using:
- `shared_access_key_enabled = false`
- `public_network_access_enabled = false`
- Azure AD authentication via `storage_use_azuread = true`

### Issue: Grants Timeout

**Error:** `cannot create grants: failed in rate limiter: context deadline exceeded`

**Solution:** The Databricks API may be rate-limited. Wait 5-10 minutes and run:

```powershell
$env:ARM_USE_CLI = "true"
terraform apply -auto-approve
```

### Issue: Email Case Sensitivity

**Error:** Grants fail with user not found

**Solution:** Unity Catalog normalizes emails to lowercase. Ensure your `metastore_admins` uses lowercase:

```hcl
# ❌ Wrong
metastore_admins = ["Admin@YourDomain.onmicrosoft.com"]

# ✅ Correct
metastore_admins = ["admin@yourdomain.onmicrosoft.com"]
```

### Issue: Permission Errors During Deployment

**Error:** `AuthorizationFailed` or insufficient permissions

**Solution:** Ensure your Azure account has:
- Contributor or Owner role on the subscription
- Permission to create service principals and role assignments

Run the pre-deployment script to verify:

```powershell
.\scripts\pre-deploy.ps1
```

## 🧹 Cleanup

To destroy all resources:

```powershell
$env:ARM_USE_CLI = "true"
terraform destroy
```

**Warning:** This will permanently delete:
- The Databricks workspace
- All Unity Catalog metadata
- Storage accounts (including data)
- All networking resources

## 📚 Next Steps

After deployment:

1. **Access the Workspace**
   - Navigate to the workspace URL from outputs
   - Sign in with your Azure AD credentials

2. **Explore Unity Catalog**
   - Browse to "Data" in the left sidebar
   - Verify `bronze_catalog_dev` catalog exists
   - Check `bronze_source1` schema

3. **Upload Sample Data**
   - Use the landing external location for data ingestion
   - Create tables in the bronze schema

4. **Create Compute Clusters**
   - Navigate to "Compute"
   - Create a cluster with Unity Catalog enabled
   - Unity Catalog is automatically configured

5. **Configure Additional Users**
   - Add users to your Azure AD tenant
   - Grant them permissions in Unity Catalog
   - Use Databricks groups for easier management

## 📖 Additional Resources

- [Azure Databricks Documentation](https://learn.microsoft.com/azure/databricks/)
- [Unity Catalog Documentation](https://docs.databricks.com/data-governance/unity-catalog/index.html)
- [Terraform Databricks Provider](https://registry.terraform.io/providers/databricks/databricks/latest/docs)
- [Azure Databricks Best Practices](https://learn.microsoft.com/azure/databricks/lakehouse-architecture/)

## 🤝 Support

For issues specific to this deployment:
1. Check the troubleshooting section above
2. Review Terraform error messages carefully
3. Verify all prerequisites are met
4. Check Azure service health for regional issues

## 📝 License

See repository LICENSE file for details.

## ✨ Features

- 🏗️ Complete infrastructure as code
- 🔐 Enterprise-grade security by default
- 🚀 Unity Catalog ready out of the box
- 📊 Pre-configured bronze layer for lakehouse architecture
- 🔄 Idempotent and repeatable deployments
- 🛡️ Compliant with Azure security policies
