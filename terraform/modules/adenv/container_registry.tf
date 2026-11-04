locals {
  acr_name = "acr${replace(var.prefix, "-", "")}${random_string.suffix.result}"
}

resource "azurerm_container_registry" "adplatformapi" {
  name                          = local.acr_name
  location                      = var.region
  resource_group_name           = data.azurerm_resource_group.ad_platform.name
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false
  network_rule_bypass_option    = "None"

  identity {
    type = "SystemAssigned"
  }

  tags = {
    client      = var.client_name
    environment = var.env_name
    managed_by  = "terraform"
  }
}


module "adplatformapi_acr_private_endpoint" {
  source = "../shared/private_endpoint"

  resource_group_name = data.azurerm_resource_group.ad_platform.name
  name                = azurerm_container_registry.adplatformapi.name
  location            = var.region
  subnet_id           = azurerm_subnet.container_registry.id

  private_dns = {
    resource_id = azurerm_private_dns_zone.container_registry.id
    name        = azurerm_private_dns_zone.container_registry.name
    a_name      = "dns-${var.prefix}-acr"
  }

  private_link_enabled_resource_id = azurerm_container_registry.adplatformapi.id
  subresource_names                = ["registry"]
  log_analytics_workspace_id       = azurerm_log_analytics_workspace.ad_platform.id
}

module "acr_diagnostic_setting" {
  source                     = "../shared/diagnostic_setting"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.ad_platform.id
  resource_id                = azurerm_container_registry.adplatformapi.id
  resource_name              = azurerm_container_registry.adplatformapi.name
  depends_on                 = [module.storage_container_private_endpoint_dfs]
}
