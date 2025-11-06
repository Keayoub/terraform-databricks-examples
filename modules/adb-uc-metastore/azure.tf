resource "azurerm_resource_group" "shared_resource_group" {
  name     = var.shared_resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_databricks_access_connector" "access_connector" {
  name                = var.access_connector_name
  resource_group_name = azurerm_resource_group.shared_resource_group.name
  location            = azurerm_resource_group.shared_resource_group.location
  identity {
    type = "SystemAssigned"
  }
  tags = var.tags
}

resource "azurerm_storage_account" "unity_catalog" {
  name                            = var.metastore_storage_name
  location                        = azurerm_resource_group.shared_resource_group.location
  resource_group_name             = var.shared_resource_group_name
  tags                            = var.tags
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  is_hns_enabled                  = true
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true  # Changed to true to allow Databricks access
  
  # Network rules to allow access from Databricks subnets
  dynamic "network_rules" {
    for_each = length(var.databricks_subnet_ids) > 0 ? [1] : []
    content {
      default_action             = "Deny"
      ip_rules                   = []
      virtual_network_subnet_ids = var.databricks_subnet_ids
      bypass                     = ["AzureServices"]
    }
  }
}

resource "azurerm_storage_container" "unity_catalog" {
  name                  = "${var.metastore_storage_name}-container"
  storage_account_id    = azurerm_storage_account.unity_catalog.id
  container_access_type = "private"
}

locals {
  # Steps 2-4 in https://learn.microsoft.com/en-us/azure/databricks/data-governance/unity-catalog/azure-managed-identities#--step-2-grant-the-managed-identity-access-to-the-storage-account
  uc_roles = [
    "Storage Blob Data Contributor",  # Normal data access
    "Storage Queue Data Contributor", # File arrival triggers
    "EventGrid EventSubscription Contributor",
  ]
}

resource "azurerm_role_assignment" "unity_catalog" {
  for_each             = toset(local.uc_roles)
  scope                = azurerm_storage_account.unity_catalog.id
  role_definition_name = each.value
  principal_id         = azurerm_databricks_access_connector.access_connector.identity[0].principal_id
}
