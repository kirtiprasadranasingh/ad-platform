mock_provider "databricks" {}

variables {
  deployment_identity_client_id = "11111111-1111-1111-1111-111111111111"
  workspace_url                 = "https://adb-123456789.1.azuredatabricks.net"
  workspace_resource_id         = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-synthetic/providers/Microsoft.Databricks/workspaces/dbw-synthetic"
  workspace_id                  = 123456789
  access_connector_id           = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-synthetic/providers/Microsoft.Databricks/accessConnectors/dbc-synthetic"
  storage_account_name          = "synthetictestdata"
  prefix                        = "synthetic-test"
  metastore_id                  = "22222222-2222-2222-2222-222222222222"
  runtime_version               = "synthetic-test-runtime"
  node_type_id                  = "synthetic-test-sku"
  owner_group                   = "synthetic-platform-owners"
  user_group                    = "synthetic-data-users"
}

run "isolated_data_boundary" {
  command = plan
  assert {
    condition     = alltrue([for catalog in databricks_catalog.environment : catalog.isolation_mode == "ISOLATED" && !catalog.force_destroy])
    error_message = "Catalogs must be isolated and protected against forced deletion."
  }
  assert {
    condition     = databricks_workspace_conf.security.custom_config.storeInteractiveNotebookResultsInCustomerAccount == "true"
    error_message = "Notebook results must remain in the customer account."
  }
  assert {
    condition     = databricks_cluster.environment.data_security_mode == "USER_ISOLATION"
    error_message = "Compute isolation must be retained."
  }
}

run "reject_all_users_as_owner" {
  command = plan
  variables { owner_group = "account users" }
  expect_failures = [var.owner_group]
}

run "reject_all_users_as_compute_group" {
  command = plan
  variables { user_group = "users" }
  expect_failures = [var.user_group]
}
