# Private access to client-owned image and authentication services. Their DNS
# records share the workload zones, avoiding NXDOMAIN from shadowing central zones.
resource "azurerm_private_endpoint" "application_registry" {
  name                = "${var.prefix}-application-registry-pe"
  resource_group_name = data.azurerm_resource_group.ad_platform.name
  location            = var.region
  subnet_id           = azurerm_subnet.container_registry.id
  private_service_connection {
    name                           = "application-registry"
    private_connection_resource_id = var.application_registry_id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "application-registry"
    private_dns_zone_ids = [azurerm_private_dns_zone.container_registry.id]
  }
}

resource "azurerm_private_endpoint" "authentication_vault" {
  name                = "${var.prefix}-authentication-vault-pe"
  resource_group_name = data.azurerm_resource_group.ad_platform.name
  location            = var.region
  subnet_id           = azurerm_subnet.keyvault.id
  private_service_connection {
    name                           = "authentication-vault"
    private_connection_resource_id = var.authentication_vault_id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "authentication-vault"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }
}
