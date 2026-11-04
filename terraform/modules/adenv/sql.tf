resource "azurerm_mssql_server" "ad_platform" {
  name                = "sql-${var.prefix}"
  resource_group_name = data.azurerm_resource_group.ad_platform.name
  location            = var.region
  version             = var.sql.version
  connection_policy   = "Proxy"
  azuread_administrator {
    login_username              = "sql-platform-admins"
    object_id                   = var.sql_admin_group_object_id
    tenant_id                   = var.tenant_id
    azuread_authentication_only = true
  }
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  tags = {
    client      = var.client_name
    environment = var.env_name
    managed_by  = "terraform"
  }
}

resource "azurerm_mssql_database" "ad_platform" {
  name                                = "db-${var.prefix}"
  server_id                           = azurerm_mssql_server.ad_platform.id
  collation                           = "SQL_Latin1_General_CP1_CI_AS"
  license_type                        = "LicenseIncluded"
  sku_name                            = "S1"
  transparent_data_encryption_enabled = true
  short_term_retention_policy { retention_days = 35 }
  lifecycle { prevent_destroy = true }

  tags = {
    client      = var.client_name
    environment = var.env_name
    managed_by  = "terraform"
  }
}


module "sql_private_endpoint" {
  source = "../shared/private_endpoint"

  resource_group_name = data.azurerm_resource_group.ad_platform.name
  name                = azurerm_mssql_server.ad_platform.name
  location            = var.region
  subnet_id           = azurerm_subnet.sql.id

  private_dns = {
    resource_id = azurerm_private_dns_zone.sql.id
    name        = azurerm_private_dns_zone.sql.name
    a_name      = "dns-${var.prefix}-sql"
  }

  private_link_enabled_resource_id = azurerm_mssql_server.ad_platform.id
  subresource_names                = ["sqlServer"]
  log_analytics_workspace_id       = azurerm_log_analytics_workspace.ad_platform.id

  depends_on = [
    azurerm_subnet_network_security_group_association.sql,
    azurerm_private_dns_zone_virtual_network_link.sql
  ]
}
