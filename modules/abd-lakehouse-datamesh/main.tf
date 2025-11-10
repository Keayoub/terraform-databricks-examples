# Catalog domaine (si non créé côté UC admin)
resource "databricks_catalog" "sales" {
  name       = var.catalog_name
  comment    = "Data domain catalog (Sales)"
  properties = {}
  # owner      = ""  # peut être défini via databricks_grants ci-dessous
}

# Schemas Medallion + reference + ml
resource "databricks_schema" "raw" {
  catalog_name = databricks_catalog.sales.name
  name         = "raw"
  comment      = "Bronze"
}

resource "databricks_schema" "curated" {
  catalog_name = databricks_catalog.sales.name
  name         = "curated"
  comment      = "Silver"
}

resource "databricks_schema" "gold" {
  catalog_name = databricks_catalog.sales.name
  name         = "gold"
  comment      = "Gold"
}

resource "databricks_schema" "reference" {
  catalog_name = databricks_catalog.sales.name
  name         = "reference"
  comment      = "Reference data"
}

resource "databricks_schema" "ml" {
  catalog_name = databricks_catalog.sales.name
  name         = "ml"
  comment      = "ML features & models"
}

# Volume Landing (si tu veux une landing séparée du raw)
resource "databricks_volume" "landing" {
  catalog_name = databricks_catalog.sales.name
  schema_name  = "landing" # Option: crée le schema "landing" si tu en veux un
  name         = "sales_landing"
  comment      = "Landing files for Sales"
  volume_type  = "MANAGED"
  depends_on   = [databricks_catalog.sales]
}

# Variante si tu préfères le Volume dans raw :
# resource "databricks_volume" "landing" {
#   catalog_name = databricks_catalog.sales.name
#   schema_name  = databricks_schema.raw.name
#   name         = "sales_landing"
#   volume_type  = "MANAGED"
# }

# Grants (RBAC UC)
resource "databricks_grants" "catalog_sales" {
  catalog = databricks_catalog.sales.name
  dynamic "grant" {
    for_each = toset(var.groups_admins)
    content {
      principal  = grant.value
      privileges = ["ALL_PRIVILEGES"]
    }
  }
  dynamic "grant" {
    for_each = toset(var.groups_writers)
    content {
      principal  = grant.value
      privileges = ["USE_CATALOG", "CREATE", "READ_VOLUME", "WRITE_VOLUME"]
    }
  }
  dynamic "grant" {
    for_each = toset(var.groups_readers)
    content {
      principal  = grant.value
      privileges = ["USE_CATALOG"]
    }
  }
}

resource "databricks_grants" "schema_raw" {
  schema = "${databricks_catalog.sales.name}.${databricks_schema.raw.name}"
  dynamic "grant" {
    for_each = toset(var.groups_writers)
    content {
      principal  = grant.value
      privileges = ["USAGE", "CREATE", "SELECT", "MODIFY"]
    }
  }

  dynamic "grant" {
    for_each = toset(var.groups_readers)
    content {
      principal  = grant.value
      privileges = ["USAGE", "SELECT"]
    }
  }
}

resource "databricks_grants" "schema_curated" {
  schema = "${databricks_catalog.sales.name}.${databricks_schema.curated.name}"
  dynamic "grant" {
    for_each = toset(var.groups_writers)
    content {
      principal  = grant.value
      privileges = ["USAGE", "CREATE", "SELECT", "MODIFY"]
    }
  }
  dynamic "grant" {
    for_each = toset(var.groups_readers)
    content {
      principal  = grant.value
      privileges = ["USAGE", "SELECT"]
    }
  }
}

resource "databricks_grants" "schema_gold" {
  schema = "${databricks_catalog.sales.name}.${databricks_schema.gold.name}"
  dynamic "grant" {
    for_each = toset(var.groups_readers)
    content {
      principal  = grant.value
      privileges = ["USAGE", "SELECT"]
    }
  }
}

resource "databricks_grants" "schema_reference" {
  schema = "${databricks_catalog.sales.name}.${databricks_schema.reference.name}"
  dynamic "grant" {
    for_each = toset(var.groups_readers)
    content {
      principal  = grant.value
      privileges = ["USAGE", "SELECT"]
    }
  }
}

resource "databricks_grants" "schema_ml" {
  schema = "${databricks_catalog.sales.name}.${databricks_schema.ml.name}"
  dynamic "grant" {
    for_each = toset(var.groups_writers)
    content {
      principal  = grant.value
      privileges = ["USAGE", "CREATE", "SELECT", "MODIFY"]
    }
  }
}

# Grant sur le Volume landing
resource "databricks_grants" "vol_landing" {
  volume = "${databricks_catalog.sales.name}.${databricks_schema.raw.name}.${databricks_volume.landing.name}"
  dynamic "grant" {
    for_each = toset(var.groups_writers)
    content {
      principal  = grant.value
      privileges = ["READ_VOLUME", "WRITE_VOLUME"]
    }
  }
}
