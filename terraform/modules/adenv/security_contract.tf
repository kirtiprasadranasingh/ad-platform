output "security_contract" {
  description = "Non-sensitive engineered invariants used by offline mock-plan tests."
  value = {
    segment_count       = length(azurerm_network_security_group.ad_platform)
    routed_subnet_count = length(azurerm_subnet_route_table_association.workload)
    private_app         = !azurerm_linux_web_app.adplatformapi.public_network_access_enabled
    entra_only_sql      = azurerm_mssql_server.ad_platform.azuread_administrator[0].azuread_authentication_only
  }
}
