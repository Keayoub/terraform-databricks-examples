# Unity Catalog Access Connector - Account Integration

## Overview

This document explains how the Access Connector's managed identity is integrated with Databricks Unity Catalog at the account level.

## Architecture

```
Azure AD Managed Identity (Access Connector)
    ↓
Databricks Account Service Principal (Auto-created)
    ↓
Unity Catalog Metastore Data Access
    ↓
Azure Storage (with RBAC permissions)
```

## Current Implementation

### What We Have ✅

Our deployment automatically handles the account-level integration through the following resources:

#### 1. Access Connector Creation
```terraform
resource "azurerm_databricks_access_connector" "access_connector" {
  name                = var.access_connector_name
  resource_group_name = azurerm_resource_group.shared_resource_group.name
  location            = azurerm_resource_group.shared_resource_group.location
  identity {
    type = "SystemAssigned"  # Creates Azure AD managed identity
  }
  tags = var.tags
}
```

**Result:** Creates an Azure resource with a system-assigned managed identity (Principal ID)

#### 2. Storage-Level RBAC
```terraform
resource "azurerm_role_assignment" "unity_catalog" {
  for_each             = toset(local.uc_roles)
  scope                = azurerm_storage_account.unity_catalog.id
  role_definition_name = each.value
  principal_id         = azurerm_databricks_access_connector.access_connector.identity[0].principal_id
}
```

**Roles Assigned:**
- Storage Blob Data Contributor (data read/write)
- Storage Queue Data Contributor (file arrival triggers)
- EventGrid EventSubscription Contributor (event subscriptions)

**Result:** The managed identity can access the storage account

#### 3. Metastore Data Access (Account-Level Integration)
```terraform
resource "databricks_metastore_data_access" "access-connector-data-access" {
  metastore_id = databricks_metastore.databricks-metastore.id
  name         = var.access_connector_name
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.access_connector.id
  }
  is_default    = true
  force_destroy = true
}
```

**Result:** This resource performs **two critical actions**:

1. **Implicitly creates a service principal** in your Databricks account for the access connector's managed identity
2. **Registers that service principal** with Unity Catalog as a data access configuration

## How It Works

### Behind the Scenes

When `databricks_metastore_data_access` is created with `azure_managed_identity`, the Databricks provider:

1. Retrieves the managed identity's Principal ID from the access connector
2. Calls the Databricks Account API to register this Principal ID as a service principal
3. Associates this service principal with the Unity Catalog metastore
4. Configures it as the default data access method (`is_default = true`)

### Verification

You can verify the account-level integration by:

```powershell
# Get the access connector's managed identity Principal ID
az ad sp show --id <principal-id-from-access-connector>

# Or check in Databricks Account Console
# Navigate to: https://accounts.azuredatabricks.net/
# Go to: User Management > Service Principals
# Look for the access connector's principal ID
```

## Alternative Approach: Explicit Service Principal Creation

If you want **explicit control** over the service principal registration, you could add this module:

```terraform
# Optional: Explicitly create service principal at account level
resource "databricks_service_principal" "access_connector_sp" {
  provider       = databricks.account
  application_id = azurerm_databricks_access_connector.access_connector.identity[0].principal_id
  display_name   = "${var.access_connector_name}-sp"
}

# Then reference it in metastore data access
resource "databricks_metastore_data_access" "access-connector-data-access" {
  metastore_id = databricks_metastore.databricks-metastore.id
  name         = var.access_connector_name
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.access_connector.id
  }
  is_default    = true
  force_destroy = true
  
  # This ensures the service principal exists first
  depends_on = [databricks_service_principal.access_connector_sp]
}
```

### When to Use Explicit Creation

✅ **Use explicit creation when:**
- You need to assign additional account-level permissions to the service principal
- You want to manage the service principal lifecycle independently
- You need better visibility in Terraform state
- You're implementing complex multi-workspace scenarios

❌ **Stick with implicit creation when:**
- Single workspace setup (our current scenario)
- Default Unity Catalog configuration is sufficient
- Simpler is better (less to manage)

## Current Deployment Status

Our deployment uses the **implicit approach** which is:
- ✅ **Recommended** by Databricks for most scenarios
- ✅ **Simpler** - fewer resources to manage
- ✅ **Sufficient** for single-workspace Unity Catalog setups
- ✅ **Works perfectly** with Azure AD authentication

## Troubleshooting

### Verify Access Connector Integration

```powershell
# 1. Get Access Connector Principal ID
$accessConnector = az databricks access-connector show `
  --name dbx-lh-connector `
  --resource-group rg-databricks-shared `
  --query "identity.principalId" -o tsv

# 2. Check storage account permissions
az role assignment list `
  --scope "/subscriptions/<subscription-id>/resourceGroups/rg-databricks-shared/providers/Microsoft.Storage/storageAccounts/dbxlhmetastore" `
  --query "[?principalId=='$accessConnector'].{Role:roleDefinitionName,Principal:principalId}" -o table

# 3. Verify in Databricks (via Databricks CLI or UI)
# The access connector should appear as a storage credential in Unity Catalog
```

### Common Issues

**Issue:** "Access denied when accessing storage"
**Solution:** Verify RBAC roles are assigned and propagated (can take 5-10 minutes)

**Issue:** "Service principal not found"
**Solution:** The service principal is created implicitly - verify `databricks_metastore_data_access` was created successfully

**Issue:** "Cannot access metastore"
**Solution:** Ensure metastore assignment to workspace is complete

## Best Practices

1. ✅ **Use managed identities** (our current approach) instead of service principal secrets
2. ✅ **Set `is_default = true`** on the primary data access configuration
3. ✅ **Use RBAC** instead of storage account keys
4. ✅ **Monitor role assignment propagation** - wait 5-10 minutes after creation
5. ✅ **Document the access connector** - it's the bridge between Azure and Databricks

## Additional Resources

- [Azure Databricks Unity Catalog with Managed Identities](https://learn.microsoft.com/en-us/azure/databricks/data-governance/unity-catalog/azure-managed-identities)
- [Databricks Metastore Data Access](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/metastore_data_access)
- [Azure Databricks Access Connector](https://learn.microsoft.com/en-us/azure/databricks/administration-guide/cloud-configurations/azure/access-connector)

## Summary

**✅ Your deployment DOES include account-level role assignment** - it's handled automatically by the `databricks_metastore_data_access` resource. The access connector's managed identity is:

1. Created in Azure AD ✅
2. Granted storage permissions via RBAC ✅
3. Registered as a Databricks account service principal ✅ (implicit)
4. Associated with Unity Catalog metastore ✅

No additional configuration is needed unless you want explicit control over the service principal registration.
