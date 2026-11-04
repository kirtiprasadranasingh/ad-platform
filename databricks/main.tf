terraform {
  required_version = ">= 1.14.0, < 2.0.0"
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "= 1.131.0"
    }
  }
  backend "azurerm" {}
}

# Phase 2 runs AFTER Azure bootstrap and private DNS/routing verification.
# No private infrastructure is constructed while configuring this provider.
provider "databricks" {
  host                        = var.workspace_url
  azure_workspace_resource_id = var.workspace_resource_id
  azure_client_id             = var.deployment_identity_client_id
  azure_use_msi               = true
}

resource "databricks_metastore_assignment" "environment" {
  workspace_id = var.workspace_id
  metastore_id = var.metastore_id
}

resource "databricks_workspace_conf" "security" {
  custom_config = {
    storeInteractiveNotebookResultsInCustomerAccount = "true"
    enableResultsDownloading                         = "false"
    enableNotebookTableClipboard                     = "false"
  }
  lifecycle { prevent_destroy = true }
}

resource "databricks_cluster" "environment" {
  cluster_name            = "cluster-${var.prefix}"
  spark_version           = var.runtime_version
  node_type_id            = var.node_type_id
  num_workers             = 1
  autotermination_minutes = 20
  data_security_mode      = "USER_ISOLATION"
  runtime_engine          = "STANDARD"
  azure_attributes { availability = "ON_DEMAND" }
  depends_on = [databricks_metastore_assignment.environment, databricks_workspace_conf.security]
}

resource "databricks_permissions" "compute" {
  cluster_id = databricks_cluster.environment.id
  access_control {
    group_name       = var.owner_group
    permission_level = "CAN_MANAGE"
  }
  access_control {
    group_name       = var.user_group
    permission_level = "CAN_ATTACH_TO"
  }
}

resource "databricks_storage_credential" "environment" {
  name           = "${replace(var.prefix, "-", "_")}_connector"
  owner          = var.owner_group
  force_destroy  = false
  isolation_mode = "ISOLATED"
  azure_managed_identity { access_connector_id = var.access_connector_id }
  depends_on = [databricks_metastore_assignment.environment]
}

resource "databricks_workspace_binding" "credential" {
  securable_name = databricks_storage_credential.environment.name
  securable_type = "storage_credential"
  workspace_id   = var.workspace_id
}

resource "databricks_external_location" "data" {
  for_each        = toset(["backups", "metastore-files"])
  name            = "${each.value}_${replace(var.prefix, "-", "_")}"
  url             = "abfss://${each.value}@${var.storage_account_name}.dfs.core.windows.net/"
  credential_name = databricks_storage_credential.environment.name
  owner           = var.owner_group
  force_destroy   = false
  isolation_mode  = "ISOLATED"
  depends_on      = [databricks_workspace_binding.credential]
}

resource "databricks_workspace_binding" "locations" {
  for_each       = databricks_external_location.data
  securable_name = each.value.name
  securable_type = "external_location"
  workspace_id   = var.workspace_id
}

resource "databricks_catalog" "environment" {
  for_each       = { backups = "backups", init_scripts = "metastore-files" }
  name           = "${each.key}_${replace(var.prefix, "-", "_")}"
  owner          = var.owner_group
  storage_root   = databricks_external_location.data[each.value].url
  force_destroy  = false
  isolation_mode = "ISOLATED"
  depends_on     = [databricks_workspace_binding.locations]
  lifecycle { prevent_destroy = true }
}

resource "databricks_workspace_binding" "catalogs" {
  for_each       = databricks_catalog.environment
  securable_name = each.value.name
  workspace_id   = var.workspace_id
}

resource "databricks_schema" "files" {
  catalog_name  = databricks_catalog.environment["init_scripts"].name
  name          = "files"
  owner         = var.owner_group
  force_destroy = false
  depends_on    = [databricks_workspace_binding.catalogs]
}

output "cluster_id" { value = databricks_cluster.environment.id }
output "catalogs" { value = { for k, v in databricks_catalog.environment : k => v.name } }
