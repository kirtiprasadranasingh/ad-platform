resource "azurerm_service_plan" "adplatformapi" {
  name                = "plan-${var.prefix}"
  location            = var.region
  os_type             = "Linux"
  resource_group_name = data.azurerm_resource_group.ad_platform.name
  sku_name            = "S1"

  tags = {
    client      = var.client_name
    environment = var.env_name
    managed_by  = "terraform"
  }
}

resource "azurerm_linux_web_app" "adplatformapi" {
  name                = "app-${var.prefix}-adplatformapi"
  location            = var.region
  resource_group_name = data.azurerm_resource_group.ad_platform.name
  service_plan_id     = azurerm_service_plan.adplatformapi.id

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  https_only                                     = true
  public_network_access_enabled                  = false
  client_certificate_enabled                     = true
  client_certificate_mode                        = "Optional"
  virtual_network_subnet_id                      = azurerm_subnet.adplatformapi.id

  app_settings = {
    MICROSOFT_PROVIDER_AUTHENTICATION_SECRET = "@Microsoft.KeyVault(SecretUri=${var.authentication_secret_uri})"
    AZURE_KEYVAULT_RESOURCEENDPOINT          = azurerm_key_vault.ad_platform.vault_uri
    AZURE_KEYVAULT_SCOPE                     = "https://vault.azure.net/.default"
    AZURE_STORAGEBLOB_RESOURCEENDPOINT       = azurerm_storage_account.ad_platform.primary_blob_endpoint
    DOCKER_ENABLE_CI                         = false
    WEBSITE_ALWAYS_FALLBACK_TO_PUBLIC_DNS    = 0
    WEBSITE_PULL_IMAGE_OVER_VNET             = true
    WEBSITES_CONTAINER_START_TIME_LIMIT      = 1800
    WEBSITES_ENABLE_APP_SERVICE_STORAGE      = true
    WEBSITES_PORT                            = 8000
  }

  site_config {
    minimum_tls_version                           = "1.2"
    scm_minimum_tls_version                       = "1.2"
    ftps_state                                    = "Disabled"
    http2_enabled                                 = true
    app_command_line                              = "./entrypoint.sh"
    vnet_route_all_enabled                        = true
    container_registry_use_managed_identity       = true
    container_registry_managed_identity_client_id = azurerm_user_assigned_identity.application.client_id

    application_stack {
      docker_image_name   = var.application_image
      docker_registry_url = "https://${var.application_registry_host}"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.application.id]
  }

  auth_settings_v2 {
    auth_enabled           = true
    require_authentication = true
    unauthenticated_action = "RedirectToLoginPage"
    default_provider       = "azureactivedirectory"

    active_directory_v2 {
      client_id                  = var.entra_application_client_id
      tenant_auth_endpoint       = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
      client_secret_setting_name = "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
    }

    login {
      token_store_enabled = true
    }
  }

  tags = {
    client      = var.client_name
    environment = var.env_name
    managed_by  = "terraform"
  }

  key_vault_reference_identity_id = azurerm_user_assigned_identity.application.id
  depends_on = [
    azurerm_subnet.adplatformapi, azurerm_role_assignment.acr_pull,
    azurerm_role_assignment.keyvault_user,
    azurerm_private_endpoint.application_registry,
    azurerm_private_endpoint.authentication_vault,
    azurerm_subnet_route_table_association.workload
  ]
}

module "adplatformapi_diagnostic_setting" {
  source                     = "../shared/diagnostic_setting"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.ad_platform.id
  resource_id                = azurerm_linux_web_app.adplatformapi.id
  resource_name              = azurerm_linux_web_app.adplatformapi.name
}
