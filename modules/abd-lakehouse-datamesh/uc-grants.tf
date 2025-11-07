###############################################################################
# Variables to configure domains and Entra ID groups
###############################################################################
variable "domains" {
  description = "List of data domains (catalogs) to configure"
  type        = list(string)
  default     = ["sales", "finance"] 
}
variable "group_data_engineers" {
  description = "Mapping domain -> data engineers group name"
  type        = map(string)
  default     = {
    sales   = "data_engineers_sales",
    finance = "data_engineers_finance"
  }
}
variable "group_bi_readers" {
  description = "Mapping domain -> BI readers group name"
  type        = map(string)
  default     = {
    sales   = "bi_readers_sales",
    finance = "bi_readers_finance"
  }
}
variable "platform_admins_group" {
  description = "Entra ID group for platform administrators (metastore admins)"
  type        = string
  default     = "data_platform_admins"
}


###############################################################################
# 1. Catalog definition by domain (one UC catalog per data domain)
###############################################################################
resource "databricks_catalog" "catalogs" {
  for_each = toset(var.domains)
  name     = "${each.value}_catalog"
  comment  = "Data catalog for the ${each.value} domain"
  provider = databricks.workspace
  # The databricks provider must be configured with the correct scopes (account / workspace)
}
# Grant permissions on each catalog
resource "databricks_grants" "catalog_permissions" {
  for_each = toset(var.domains)
  catalog  = "${each.value}_catalog"
  # Full rights for platform admins (ALL PRIVILEGES includes SELECT/MODIFY/USAGE, except MANAGE)
  grant {
    principal  = var.platform_admins_group
    privileges = ["ALL PRIVILEGES", "MANAGE"]
  }
  # Rights for domain data engineers group: owner/catalog admin of the domain
  grant {
    principal  = var.group_data_engineers[each.value]
    privileges = ["CREATE SCHEMA", "USE CATALOG"]
  }
  # (Optional) Allow catalog discovery by others (BROWSE)
  grant {
    principal  = "users"  # special alias for All Users group in Databricks
    privileges = ["BROWSE"]
  }
}

###############################################################################
# 2. Schema definition by domain and by layer (raw, curated, gold, etc.)
###############################################################################
locals {
  layers = ["raw", "curated", "gold", "reference", "ml"]
  # Permission types by layer (modifiable according to governance rules)
  layer_perms = {
    raw = {        
      writer_privs = ["CREATE TABLE", "CREATE VOLUME", "MODIFY", "SELECT"]  # Engineers can write and read raw       
      reader_privs = []                                                     # No BI readers on raw
    },
    curated = {
      writer_privs = ["CREATE TABLE", "MODIFY", "SELECT"]   # Engineers write (and read)        
      reader_privs = []                                     # No BI readers by default on curated      
    },
    gold = {
      writer_privs = ["CREATE TABLE", "MODIFY", "SELECT"]   # Engineers write gold tables
      reader_privs = ["SELECT"]                             # BI readers have SELECT on gold
    },
    reference = {
        
      writer_privs = ["CREATE TABLE", "MODIFY", "SELECT"]   # Engineers write reference tables
      reader_privs = ["SELECT"]                             # BI readers have SELECT on reference
    },
    ml = {        
      writer_privs = ["CREATE TABLE", "CREATE VOLUME", "MODIFY", "SELECT"]  # Engineers write ML tables & volumes        
      reader_privs = []                                                     # (No BI readers on ml by default)
    }
  }
}

# Create schemas for each (domain, layer)
variable "layers" {
  description = "List of data layers to create in each domain"
  type        = list(string)
  default     = ["raw", "curated", "gold", "reference", "ml"]
}

resource "databricks_schema" "schemas" {
  for_each = {
    for domain in var.domains :
    domain => {
      domain = domain
      layers = var.layers
    }
  }
  catalog_name = "${each.value.domain}_catalog"
  # Create a schema for each layer in each domain
  # Use a separate resource or module block for each schema if needed
  # Here, example for the "raw" layer (to be adapted for all layers)
  name = "raw"
}

# Nested loop for grants on each schema of each domain
resource "databricks_grants" "schema_permissions" {  
  for_each = {
    for pair in setproduct(var.domains, local.layers) :
    "${pair[0]}_${pair[1]}" => { domain = pair[0], layer = pair[1] }
  }
  schema = "${each.value.domain}_catalog.${each.value.layer}"
  # Platform admin privileges on the schema
  grant {
    principal  = var.platform_admins_group
    privileges = ["ALL PRIVILEGES", "MANAGE"]
  }
  # Domain data engineers group privileges on this schema (write)
  grant {
    principal  = var.group_data_engineers[each.value.domain]
    privileges = local.layer_perms[each.value.layer].writer_privs
  }
  # Domain BI readers group privileges on this schema (read, if applicable)
  dynamic "grant" {
    for_each = length(local.layer_perms[each.value.layer].reader_privs) > 0 ? [1] : []
    content {
      principal  = var.group_bi_readers[each.value.domain]
      privileges = local.layer_perms[each.value.layer].reader_privs
    }
  }
}


###############################################################################
# 3. Grant privileges on all current and future tables in gold/reference schemas
# (so that BI readers have access to all tables without manual intervention)
###############################################################################
resource "databricks_grants" "gold_tables_select" {
  for_each = toset(var.domains)
  schema   = "${each.value}_catalog.gold"
  grant {
    principal  = var.group_bi_readers[each.value]
    privileges = ["SELECT"]  # 'SELECT' on the schema is equivalent to SELECT on all current tables in the schema
  }
  # Grant future tables via 'grant on future' option of the databricks provider (not directly illustrated here)
  # The Terraform Databricks provider manages privileges on future objects via specific arguments if supported.
}