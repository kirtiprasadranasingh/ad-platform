# Private endpoints use the existing non-delegated endpoint subnet, not the
# delegated Databricks or App Service integration subnets.
resource "azurerm_private_dns_zone" "databricks" {
  name                = "privatelink.azuredatabricks.net"
  resource_group_name = data.azurerm_resource_group.ad_platform.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "databricks" {
  name                  = "${var.prefix}-databricks-link"
  private_dns_zone_name = azurerm_private_dns_zone.databricks.name
  resource_group_name   = data.azurerm_resource_group.ad_platform.name
  virtual_network_id    = azurerm_virtual_network.ad_platform.id
}

resource "azurerm_private_endpoint" "databricks_ui_api" {
  name                = "${var.prefix}-databricks-api-pe"
  location            = var.region
  resource_group_name = data.azurerm_resource_group.ad_platform.name
  subnet_id           = azurerm_subnet.container_registry.id
  private_service_connection {
    name                           = "databricks-ui-api"
    private_connection_resource_id = azurerm_databricks_workspace.ad_platform.id
    subresource_names              = ["databricks_ui_api"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "databricks"
    private_dns_zone_ids = [azurerm_private_dns_zone.databricks.id]
  }
  depends_on = [azurerm_private_dns_zone_virtual_network_link.databricks]
}

# For a single-workspace isolated DNS zone. A shared regional design must use
# a dedicated browser-authentication workspace instead; see the release gates.
resource "azurerm_private_endpoint" "databricks_browser_auth" {
  name                = "${var.prefix}-databricks-auth-pe"
  location            = var.region
  resource_group_name = data.azurerm_resource_group.ad_platform.name
  subnet_id           = azurerm_subnet.container_registry.id
  private_service_connection {
    name                           = "databricks-browser-auth"
    private_connection_resource_id = azurerm_databricks_workspace.ad_platform.id
    subresource_names              = ["browser_authentication"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "databricks"
    private_dns_zone_ids = [azurerm_private_dns_zone.databricks.id]
  }
}

resource "azurerm_private_dns_zone" "app_service" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = data.azurerm_resource_group.ad_platform.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "app_service" {
  name                  = "${var.prefix}-app-link"
  private_dns_zone_name = azurerm_private_dns_zone.app_service.name
  resource_group_name   = data.azurerm_resource_group.ad_platform.name
  virtual_network_id    = azurerm_virtual_network.ad_platform.id
}

resource "azurerm_private_endpoint" "app_service" {
  name                = "${var.prefix}-app-pe"
  location            = var.region
  resource_group_name = data.azurerm_resource_group.ad_platform.name
  subnet_id           = azurerm_subnet.container_registry.id
  private_service_connection {
    name                           = "app-service"
    private_connection_resource_id = azurerm_linux_web_app.adplatformapi.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "app-service"
    private_dns_zone_ids = [azurerm_private_dns_zone.app_service.id]
  }
}

module "blob_data_plane_diagnostics" {
  source                     = "../shared/diagnostic_setting"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.ad_platform.id
  resource_id                = "${azurerm_storage_account.ad_platform.id}/blobServices/default"
  resource_name              = "${azurerm_storage_account.ad_platform.name}-blob"
}

module "sql_database_diagnostics" {
  source                     = "../shared/diagnostic_setting"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.ad_platform.id
  resource_id                = azurerm_mssql_database.ad_platform.id
  resource_name              = azurerm_mssql_database.ad_platform.name
}

resource "azurerm_mssql_server_extended_auditing_policy" "ad_platform" {
  server_id              = azurerm_mssql_server.ad_platform.id
  log_monitoring_enabled = true
}
