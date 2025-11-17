# ====================================================================================================
# Compute Resources for Domain-Specific Data Mesh
# ====================================================================================================
# This file defines compute resources (cluster policies, SQL warehouses) for a specific domain.
# These resources complement the Unity Catalog setup defined in sql/uc-roles-grants.sql
#
# Prerequisites:
#   - Domain-specific security groups must exist in Azure AD/Entra ID
#   - Unity Catalog must be enabled on the workspace
# ====================================================================================================

variable "domain_name" {
  description = "Domain name (e.g., 'amrnet', 'finance', 'sales')"
  type        = string
}

variable "workspace_id" {
  description = "Databricks workspace ID"
  type        = string
}

variable "max_dbu_per_hour" {
  description = "Maximum DBU per hour limit for cluster policy"
  type        = number
  default     = 10
}

# ====================================================================================================
# 1. Data Engineering Cluster Policy
# ====================================================================================================
resource "databricks_cluster_policy" "data_engineering" {
  name = "${var.domain_name}_data_engineering_policy"

  definition = jsonencode({
    "spark_version" : {
      "type" : "regex",
      "pattern" : ".*-scala2.12",
      "defaultValue" : data.databricks_spark_version.latest_lts.id
    },
    "node_type_id" : {
      "type" : "allowlist",
      "values" : [
        data.databricks_node_type.smallest.id
      ],
      "defaultValue" : data.databricks_node_type.smallest.id
    },
    "driver_node_type_id" : {
      "type" : "allowlist",
      "values" : [
        data.databricks_node_type.smallest.id
      ],
      "defaultValue" : data.databricks_node_type.smallest.id
    },
    "autotermination_minutes" : {
      "type" : "fixed",
      "value" : 30,
      "hidden" : false
    },
    "autoscale.min_workers" : {
      "type" : "range",
      "minValue" : 1,
      "maxValue" : 5,
      "defaultValue" : 1
    },
    "autoscale.max_workers" : {
      "type" : "range",
      "minValue" : 2,
      "maxValue" : 20,
      "defaultValue" : 10
    },
    "dbus_per_hour" : {
      "type" : "range",
      "maxValue" : var.max_dbu_per_hour
    },
    "custom_tags.Domain" : {
      "type" : "fixed",
      "value" : var.domain_name
    },
    "data_security_mode" : {
      "type" : "fixed",
      "value" : "USER_ISOLATION",
      "hidden" : true
    },
    "spark_conf.spark.databricks.cluster.profile" : {
      "type" : "fixed",
      "value" : "singleNode",
      "hidden" : false
    }
  })
}

# Grant policy access to data engineers
resource "databricks_permissions" "data_engineering_policy" {
  cluster_policy_id = databricks_cluster_policy.data_engineering.id

  access_control {
    group_name       = "${var.domain_name}_data_engineers"
    permission_level = "CAN_USE"
  }
}

# ====================================================================================================
# 2. Data Science / ML Cluster Policy
# ====================================================================================================
resource "databricks_cluster_policy" "data_science" {
  name = "${var.domain_name}_data_science_policy"

  definition = jsonencode({
    "spark_version" : {
      "type" : "regex",
      "pattern" : ".*-ml-scala2.12",
      "defaultValue" : data.databricks_spark_version.ml.id
    },
    "node_type_id" : {
      "type" : "allowlist",
      "values" : [
        data.databricks_node_type.smallest.id
      ],
      "defaultValue" : data.databricks_node_type.smallest.id
    },
    "driver_node_type_id" : {
      "type" : "allowlist",
      "values" : [
        data.databricks_node_type.smallest.id
      ],
      "defaultValue" : data.databricks_node_type.smallest.id
    },
    "autotermination_minutes" : {
      "type" : "fixed",
      "value" : 30,
      "hidden" : false
    },
    "num_workers" : {
      "type" : "range",
      "minValue" : 0,
      "maxValue" : 10,
      "defaultValue" : 0
    },
    "dbus_per_hour" : {
      "type" : "range",
      "maxValue" : var.max_dbu_per_hour
    },
    "custom_tags.Domain" : {
      "type" : "fixed",
      "value" : var.domain_name
    },
    "data_security_mode" : {
      "type" : "fixed",
      "value" : "SINGLE_USER",
      "hidden" : true
    }
  })
}

# Grant policy access to data scientists
resource "databricks_permissions" "data_science_policy" {
  cluster_policy_id = databricks_cluster_policy.data_science.id

  access_control {
    group_name       = "${var.domain_name}_data_scientists"
    permission_level = "CAN_USE"
  }
}

# ====================================================================================================
# 3. SQL Warehouse for BI and Analytics
# ====================================================================================================
resource "databricks_sql_endpoint" "domain_warehouse" {
  name             = "${var.domain_name}_sql_warehouse"
  cluster_size     = "Small"
  max_num_clusters = 3
  auto_stop_mins   = 10

  tags {
    custom_tags = {
      Domain      = var.domain_name
      Environment = "production"
      Type        = "sql-warehouse"
    }
  }

  # Enable Serverless (if available in your workspace)
  enable_serverless_compute = true

  # Photon acceleration
  enable_photon = true
}

# SQL Warehouse permissions
resource "databricks_permissions" "sql_warehouse" {
  sql_endpoint_id = databricks_sql_endpoint.domain_warehouse.id

  access_control {
    group_name       = "data_platform_admins"
    permission_level = "CAN_MANAGE"
  }

  access_control {
    group_name       = "${var.domain_name}_data_engineers"
    permission_level = "CAN_USE"
  }

  access_control {
    group_name       = "${var.domain_name}_data_scientists"
    permission_level = "CAN_USE"
  }

  access_control {
    group_name       = "${var.domain_name}_bi_readers"
    permission_level = "CAN_USE"
  }
}

# ====================================================================================================
# 4. Shared Interactive Cluster for Data Engineering
# ====================================================================================================
resource "databricks_cluster" "data_engineering_shared" {
  cluster_name            = "${var.domain_name}_data_engineering_shared"
  spark_version           = data.databricks_spark_version.latest_lts.id
  node_type_id            = data.databricks_node_type.smallest.id
  policy_id               = databricks_cluster_policy.data_engineering.id
  autotermination_minutes = 30
  data_security_mode      = "USER_ISOLATION"

  autoscale {
    min_workers = 1
    max_workers = 10
  }

  custom_tags = {
    Domain = var.domain_name
    Type   = "shared-interactive"
    Team   = "data-engineering"
  }

  # Unity Catalog configuration
  spark_conf = {
    "spark.databricks.cluster.profile" : "singleNode"
  }
}

# Shared cluster permissions
resource "databricks_permissions" "data_engineering_cluster" {
  cluster_id = databricks_cluster.data_engineering_shared.id

  access_control {
    group_name       = "${var.domain_name}_data_engineers"
    permission_level = "CAN_RESTART"
  }

  access_control {
    group_name       = "data_platform_admins"
    permission_level = "CAN_MANAGE"
  }
}

# ====================================================================================================
# 5. Optional: Instance Pool for Faster Startup
# ====================================================================================================
resource "databricks_instance_pool" "data_engineering" {
  instance_pool_name = "${var.domain_name}_engineering_pool"
  min_idle_instances = 0
  max_capacity       = 20
  node_type_id       = data.databricks_node_type.smallest.id
  idle_instance_autotermination_minutes = 15

  custom_tags = {
    Domain = var.domain_name
    Type   = "instance-pool"
  }

  preloaded_spark_versions = [
    data.databricks_spark_version.latest_lts.id
  ]
}

# Instance pool permissions
resource "databricks_permissions" "instance_pool" {
  instance_pool_id = databricks_instance_pool.data_engineering.id

  access_control {
    group_name       = "${var.domain_name}_data_engineers"
    permission_level = "CAN_ATTACH_TO"
  }

  access_control {
    group_name       = "${var.domain_name}_data_scientists"
    permission_level = "CAN_ATTACH_TO"
  }

  access_control {
    group_name       = "data_platform_admins"
    permission_level = "CAN_MANAGE"
  }
}

# ====================================================================================================
# Data Sources
# ====================================================================================================
data "databricks_node_type" "smallest" {
  local_disk = true
}

data "databricks_spark_version" "latest_lts" {
  long_term_support = true
}

data "databricks_spark_version" "ml" {
  ml                = true
  long_term_support = true
}

# ====================================================================================================
# Outputs
# ====================================================================================================
output "data_engineering_policy_id" {
  description = "ID of the data engineering cluster policy"
  value       = databricks_cluster_policy.data_engineering.id
}

output "data_science_policy_id" {
  description = "ID of the data science cluster policy"
  value       = databricks_cluster_policy.data_science.id
}

output "sql_warehouse_id" {
  description = "ID of the domain SQL warehouse"
  value       = databricks_sql_endpoint.domain_warehouse.id
}

output "shared_cluster_id" {
  description = "ID of the shared data engineering cluster"
  value       = databricks_cluster.data_engineering_shared.id
}

output "instance_pool_id" {
  description = "ID of the engineering instance pool"
  value       = databricks_instance_pool.data_engineering.id
}

# ====================================================================================================
# 6. Library Management
# ====================================================================================================

# Create a requirements file in the ML volume for reproducibility
resource "databricks_file" "data_science_requirements" {
  source = "${path.module}/libraries/data-science-requirements.txt"
  path   = "/Volumes/${var.domain_name}_catalog/ml/configs/requirements.txt"
}

# Cluster libraries for Data Engineering
resource "databricks_library" "data_engineering_pandas" {
  cluster_id = databricks_cluster.data_engineering_shared.id
  pypi {
    package = "pandas>=2.0.0"
  }
}

resource "databricks_library" "data_engineering_pyarrow" {
  cluster_id = databricks_cluster.data_engineering_shared.id
  pypi {
    package = "pyarrow>=10.0.0"
  }
}

resource "databricks_library" "data_engineering_great_expectations" {
  cluster_id = databricks_cluster.data_engineering_shared.id
  pypi {
    package = "great-expectations>=0.17.0"
  }
}

resource "databricks_library" "data_engineering_azure_storage" {
  cluster_id = databricks_cluster.data_engineering_shared.id
  pypi {
    package = "azure-storage-blob>=12.0.0"
  }
}

# ====================================================================================================
# 7. Cluster with ML/Bio Libraries
# ====================================================================================================
resource "databricks_cluster" "data_science_bio" {
  cluster_name            = "${var.domain_name}_data_science_bio"
  spark_version           = data.databricks_spark_version.ml.id
  node_type_id            = data.databricks_node_type.smallest.id
  policy_id               = databricks_cluster_policy.data_science.id
  autotermination_minutes = 30
  data_security_mode      = "SINGLE_USER"
  single_user_name        = var.default_data_scientist_user # Variable for single user

  num_workers = 0 # Single node for ML experimentation

  custom_tags = {
    Domain   = var.domain_name
    Type     = "ml-bio-cluster"
    Team     = "data-science"
    Purpose  = "bioinformatics"
  }

  library {
    pypi {
      package = "biopython>=1.81"
    }
  }

  library {
    pypi {
      package = "scikit-learn>=1.3.0"
    }
  }

  library {
    pypi {
      package = "numpy>=1.24.0"
    }
  }

  library {
    pypi {
      package = "scipy>=1.11.0"
    }
  }

  library {
    pypi {
      package = "mlflow>=2.8.0"
    }
  }

  library {
    pypi {
      package = "pandas>=2.0.0"
    }
  }

  library {
    pypi {
      package = "matplotlib>=3.7.0"
    }
  }

  library {
    pypi {
      package = "seaborn>=0.12.0"
    }
  }
}

# Permissions for bio cluster
resource "databricks_permissions" "data_science_bio_cluster" {
  cluster_id = databricks_cluster.data_science_bio.id

  access_control {
    group_name       = "${var.domain_name}_data_scientists"
    permission_level = "CAN_ATTACH_TO"
  }

  access_control {
    group_name       = "data_platform_admins"
    permission_level = "CAN_MANAGE"
  }
}

# ====================================================================================================
# 8. Init Script for Additional System Dependencies
# ====================================================================================================
resource "databricks_dbfs_file" "bio_init_script" {
  source = "${path.module}/init-scripts/bio-dependencies.sh"
  path   = "dbfs:/databricks/init-scripts/${var.domain_name}/bio-dependencies.sh"
}

# Example cluster with init script
resource "databricks_cluster" "data_science_advanced" {
  cluster_name            = "${var.domain_name}_data_science_advanced"
  spark_version           = data.databricks_spark_version.ml.id
  node_type_id            = data.databricks_node_type.smallest.id
  policy_id               = databricks_cluster_policy.data_science.id
  autotermination_minutes = 30
  data_security_mode      = "SINGLE_USER"

  num_workers = 0

  custom_tags = {
    Domain  = var.domain_name
    Type    = "ml-advanced-cluster"
    Team    = "data-science"
  }

  init_scripts {
    dbfs {
      destination = databricks_dbfs_file.bio_init_script.path
    }
  }

  # Core ML libraries
  library {
    pypi {
      package = "tensorflow>=2.13.0"
    }
  }

  library {
    pypi {
      package = "torch>=2.0.0"
    }
  }

  library {
    pypi {
      package = "transformers>=4.30.0"
    }
  }
}

# ====================================================================================================
# Additional Variables
# ====================================================================================================
variable "default_data_scientist_user" {
  description = "Default user email for single-user clusters"
  type        = string
  default     = ""
}

