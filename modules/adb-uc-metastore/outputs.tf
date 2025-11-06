output "metastore_id" {
  value = databricks_metastore.databricks-metastore.id
}

output "access_connector_id" {
  value       = azurerm_databricks_access_connector.access_connector.id
  description = "the id of the access connector"
}

output "access_connector_principal_id" {
  value       = azurerm_databricks_access_connector.access_connector.identity[0].principal_id
  description = "The Principal ID of the System Assigned Managed Service Identity that is configured on this Access Connector"
}

output "metastore_storage_id" {
  value       = azurerm_storage_account.unity_catalog.id
  description = "The resource ID of the storage account used for Unity Catalog metastore"
}
