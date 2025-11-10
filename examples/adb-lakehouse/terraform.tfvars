subscription_id = "c7b690b3-d9ad-4ed0-9942-4e7a36d0c187" # Azure Subscription ID
account_id      = "b90dde1c-048c-4a28-b7d1-6c7c4df24b90" # Databricks Account ID

location                        = "eastus2"
existing_resource_group_name    = "rg-databricks-lakehouse"
project_name                    = "dbx-lakehouse"
environment_name                = "dev"
databricks_workspace_name       = "dbx-lakehouse-workspace"
spoke_vnet_address_space        = "10.178.0.0/16"
private_subnet_address_prefixes = ["10.178.0.0/20"]
public_subnet_address_prefixes  = ["10.178.16.0/20"]
shared_resource_group_name      = "rg-databricks-shared"
metastore_name                  = "dbxlakehousemetastore" # unity catalog metastore name
metastore_storage_name          = "dbxlhmetastore"        # storage account name must be globally unique
access_connector_name           = "dbx-lh-connector"
landing_external_location_name  = "dbxlhlanding"
landing_adls_path               = "abfss://landing@dbxlhlanding.dfs.core.windows.net" # Data lake storage path for landing zone
landing_adls_rg                 = "rg-databricks-shared"
metastore_admins                = ["admin@mngenvmcap612651.onmicrosoft.com"]

tags = {
  Owner       = "admin@mngenvmcap612651.onmicrosoft.com"
  Environment = "dev"
  Project     = "databricks-lakehouse"
}