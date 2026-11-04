resource "azurerm_private_endpoint" "main" {
  name                = "${var.name}-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.name}-private-service-connection"
    is_manual_connection           = false
    private_connection_resource_id = var.private_link_enabled_resource_id
    subresource_names              = var.subresource_names
  }

  private_dns_zone_group {
    name                 = var.private_dns.name
    private_dns_zone_ids = [var.private_dns.resource_id]
  }
}

module "diagnostic_setting" {
  source                     = "../diagnostic_setting"
  log_analytics_workspace_id = var.log_analytics_workspace_id
  resource_id                = azurerm_private_endpoint.main.network_interface[0].id
  resource_name              = azurerm_private_endpoint.main.network_interface[0].name
}

resource "azurerm_private_dns_a_record" "main" {
  name                = var.private_dns.a_name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  zone_name           = var.private_dns.name
  records             = [azurerm_private_endpoint.main.private_service_connection.0.private_ip_address]
}
