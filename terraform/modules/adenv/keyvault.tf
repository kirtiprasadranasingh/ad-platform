data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "ad_platform" {
  name                          = "kv-${var.prefix}-${random_string.suffix.result}"
  location                      = var.region
  resource_group_name           = data.azurerm_resource_group.ad_platform.name
  sku_name                      = var.keyvault.sku_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  public_network_access_enabled = false
  network_acls {
    default_action = "Deny"
    bypass         = "None"
  }
  lifecycle { prevent_destroy = true }

  tags = {
    client      = var.client_name
    environment = var.env_name
    managed_by  = "terraform"
  }
}

module "keyvault_private_endpoint" {
  source = "../shared/private_endpoint"

  resource_group_name = data.azurerm_resource_group.ad_platform.name
  name                = azurerm_key_vault.ad_platform.name
  location            = var.region
  subnet_id           = azurerm_subnet.keyvault.id

  private_dns = {
    resource_id = azurerm_private_dns_zone.keyvault.id
    name        = azurerm_private_dns_zone.keyvault.name
    a_name      = "dns-${var.prefix}-keyvault"
  }

  private_link_enabled_resource_id = azurerm_key_vault.ad_platform.id
  subresource_names                = ["Vault"]
  depends_on                       = [azurerm_private_dns_zone.keyvault]
  log_analytics_workspace_id       = azurerm_log_analytics_workspace.ad_platform.id
}

module "keyvault_diagnostic_setting" {
  source                     = "../shared/diagnostic_setting"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.ad_platform.id
  resource_id                = azurerm_key_vault.ad_platform.id
  resource_name              = azurerm_key_vault.ad_platform.name
}
