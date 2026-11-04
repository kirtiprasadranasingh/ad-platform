variable "deployment_identity_client_id" { type = string }
variable "workspace_url" {
  type = string
  validation {
    condition     = can(regex("^https://adb-[0-9]+\\.[0-9]+\\.azuredatabricks\\.net$", var.workspace_url))
    error_message = "Use the exact HTTPS Azure Databricks workspace URL from phase 1."
  }
}
variable "workspace_resource_id" { type = string }
variable "workspace_id" { type = number }
variable "access_connector_id" { type = string }
variable "storage_account_name" { type = string }
variable "prefix" { type = string }
variable "metastore_id" {
  type        = string
  description = "Existing client-governed regional metastore. Never created/destroyed by an individual environment."
}
variable "runtime_version" {
  type        = string
  description = "Explicit compliance-profile-supported runtime ID; no automatic latest selection."
}
variable "node_type_id" {
  type        = string
  description = "Compute SKU supported in the region and compliance security profile."
}
variable "owner_group" {
  type = string
  validation {
    condition     = length(trimspace(var.owner_group)) > 0 && !contains(["users", "account users"], lower(var.owner_group))
    error_message = "A restricted pre-provisioned owner group is required."
  }
}
variable "user_group" {
  type = string
  validation {
    condition     = length(trimspace(var.user_group)) > 0 && !contains(["users", "account users"], lower(var.user_group)) && var.user_group != var.owner_group
    error_message = "Supply a restricted, separate workload-user group."
  }
}
