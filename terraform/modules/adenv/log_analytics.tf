resource "azurerm_log_analytics_workspace" "ad_platform" {
  name                = "log-${var.prefix}"
  location            = var.region
  resource_group_name = data.azurerm_resource_group.ad_platform.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics.retentions_in_days

  tags = {
    client      = var.client_name
    environment = var.env_name
    managed_by  = "terraform"
  }
}
