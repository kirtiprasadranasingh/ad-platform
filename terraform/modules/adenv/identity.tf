resource "azurerm_user_assigned_identity" "application" {
  name                = "id-${var.prefix}-app"
  location            = var.region
  resource_group_name = data.azurerm_resource_group.ad_platform.name
}
