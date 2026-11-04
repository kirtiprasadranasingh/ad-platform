resource "azurerm_role_assignment" "databricks_access_connector_blob_contributor" {
  scope                = azurerm_storage_account.ad_platform.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.ad_platform.identity[0].principal_id
}

resource "azurerm_role_assignment" "acr_pull" {
  principal_id         = azurerm_user_assigned_identity.application.principal_id
  scope                = var.application_registry_id
  role_definition_name = "AcrPull"
}

resource "azurerm_role_assignment" "blob_owner" {
  principal_id         = azurerm_user_assigned_identity.application.principal_id
  scope                = azurerm_storage_account.ad_platform.id
  role_definition_name = "Storage Blob Data Contributor"
}


resource "azurerm_role_assignment" "keyvault_user" {
  principal_id         = azurerm_user_assigned_identity.application.principal_id
  scope                = var.authentication_vault_id
  role_definition_name = "Key Vault Secrets User"
}
