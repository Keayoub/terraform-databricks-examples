variable "tenant_id" {
  type        = string
  description = "The Azure AD tenant ID."
}

variable "client_id" {
  type        = string
  description = "The Azure AD client ID."
}

variable "client_secret" {
  type        = string
  description = "The Azure AD client secret."
}

variable "databricks_host" {
  type        = string
  description = "The Databricks workspace URL."
}

# Domain/catalog
variable "catalog_name" {
  type    = string
  default = "sales_catalog"
}

variable "groups_readers" {
  type    = list(string)
  default = []
} # ex: ["data_analysts"]

variable "groups_writers" {
  type    = list(string)
  default = []
} # ex: ["data_engineers"]

variable "groups_admins" {
  type    = list(string)
  default = []
} # ex: ["data_platform_admins"]
