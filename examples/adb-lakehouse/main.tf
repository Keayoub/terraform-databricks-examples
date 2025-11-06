# Create landing storage account for external location
resource "azurerm_storage_account" "landing" {
  name                            = var.landing_external_location_name
  resource_group_name             = var.shared_resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  is_hns_enabled                  = true
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true  # Changed to true to allow Databricks access
  tags                            = var.tags
  
  # Network rules to allow access from Databricks subnets
  network_rules {
    default_action             = "Deny"
    ip_rules                   = []
    virtual_network_subnet_ids = [
      module.adb-lakehouse.private_subnet_id,
      module.adb-lakehouse.public_subnet_id
    ]
    bypass = ["AzureServices"]
  }
  
  depends_on = [module.adb-lakehouse-uc-metastore, module.adb-lakehouse]
}

# Commenting out as container already exists and storage account has restricted network access
# resource "azurerm_storage_container" "landing" {
#   name                  = "landing"
#   storage_account_id    = azurerm_storage_account.landing.id
#   container_access_type = "private"
# }

module "adb-lakehouse-uc-metastore" {
  source                     = "../../modules/adb-uc-metastore"
  metastore_storage_name     = var.metastore_storage_name
  metastore_name             = var.metastore_name
  access_connector_name      = var.access_connector_name
  shared_resource_group_name = var.shared_resource_group_name
  location                   = var.location
  tags                       = var.tags
  databricks_subnet_ids      = []  # Will be configured after workspace creation
  providers = {
    databricks = databricks.account
  }
}

module "adb-lakehouse" {
  # With UC by default we need to explicitly create a UC metastore, otherwise it will be created automatically
  depends_on                      = [module.adb-lakehouse-uc-metastore]
  source                          = "../../modules/adb-lakehouse"
  project_name                    = var.project_name
  environment_name                = var.environment_name
  location                        = var.location
  spoke_vnet_address_space        = var.spoke_vnet_address_space
  existing_resource_group_name    = var.existing_resource_group_name
  create_resource_group           = var.create_resource_group
  managed_resource_group_name     = var.managed_resource_group_name
  databricks_workspace_name       = var.databricks_workspace_name
  data_factory_name               = var.data_factory_name
  key_vault_name                  = var.key_vault_name
  private_subnet_address_prefixes = var.private_subnet_address_prefixes
  public_subnet_address_prefixes  = var.public_subnet_address_prefixes
  storage_account_names           = var.storage_account_names
  tags                            = var.tags
}

module "adb-lakehouse-uc-idf-assignment" {
  depends_on         = [module.adb-lakehouse-uc-account-principals]
  source             = "../../modules/uc-idf-assignment"
  workspace_id       = module.adb-lakehouse.workspace_id
  metastore_id       = module.adb-lakehouse-uc-metastore.metastore_id
  service_principals = var.service_principals
  account_groups     = var.account_groups
  providers = {
    databricks = databricks.account
  }
}

module "adb-lakehouse-uc-account-principals" {
  source             = "../../modules/adb-lakehouse-uc/account-principals"
  service_principals = var.service_principals
  providers = {
    databricks = databricks.account
  }
}

# Configure network rules for metastore storage to allow Databricks access
resource "azurerm_storage_account_network_rules" "metastore_network_rules" {
  storage_account_id = module.adb-lakehouse-uc-metastore.metastore_storage_id
  
  default_action             = "Deny"
  ip_rules                   = []
  virtual_network_subnet_ids = [
    module.adb-lakehouse.private_subnet_id,
    module.adb-lakehouse.public_subnet_id
  ]
  bypass = ["AzureServices"]
  
  depends_on = [module.adb-lakehouse]
}

module "adb-lakehouse-data-assets" {
  depends_on                     = [module.adb-lakehouse-uc-account-principals, azurerm_storage_account.landing, azurerm_storage_account_network_rules.metastore_network_rules]
  source                         = "../../modules/adb-lakehouse-uc/uc-data-assets"
  environment_name               = var.environment_name
  storage_credential_name        = var.access_connector_name
  metastore_id                   = module.adb-lakehouse-uc-metastore.metastore_id
  access_connector_id            = module.adb-lakehouse-uc-metastore.access_connector_principal_id
  landing_external_location_name = var.landing_external_location_name
  landing_adls_path              = var.landing_adls_path
  landing_adls_rg                = var.landing_adls_rg
  metastore_admins               = var.metastore_admins
  providers = {
    databricks = databricks.workspace
  }
}
