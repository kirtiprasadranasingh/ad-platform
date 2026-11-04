resource "azurerm_management_lock" "environment" {
  name       = "protect-${var.prefix}"
  scope      = data.azurerm_resource_group.ad_platform.id
  lock_level = "CanNotDelete"
  notes      = "Production data boundary. Removal requires separately approved decommission and backup verification."
}
