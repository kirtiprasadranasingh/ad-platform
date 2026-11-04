output "id" {
  description = "AD Platform resource group ID"
  value       = data.azurerm_resource_group.ad_platform.id
}

output "name" {
  description = "AD Platform resource group name"
  value       = data.azurerm_resource_group.ad_platform.name
}

output "location" {
  description = "AD Platform resource group location"
  value       = var.region
}

output "keyvault_endpoint" {
  description = "Key Vault vault URI"
  value       = azurerm_key_vault.ad_platform.vault_uri
}

output "keyvault_id" {
  description = "Key Vault resource ID"
  value       = azurerm_key_vault.ad_platform.id
}

output "blob_endpoint" {
  description = "Storage Account primary blob endpoint"
  value       = azurerm_storage_account.ad_platform.primary_blob_endpoint
}

output "adplatformapi_subnet_id" {
  description = "AD Platform API subnet ID"
  value       = azurerm_subnet.adplatformapi.id
}

output "acr_subnet_id" {
  description = "Container Registry subnet ID"
  value       = azurerm_subnet.container_registry.id
}

output "acr_dns_id" {
  description = "Container Registry private DNS zone ID"
  value       = azurerm_private_dns_zone.container_registry.id
}

output "acr_dns_name" {
  description = "Container Registry private DNS zone name"
  value       = azurerm_private_dns_zone.container_registry.name
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = azurerm_log_analytics_workspace.ad_platform.id
}

output "app_service_url" {
  description = "AD Platform API App Service URL"
  value       = "https://app-${var.prefix}-adplatformapi.azurewebsites.net"
}

output "databricks_workspace_url" {
  description = "Databricks workspace URL"
  value       = "https://${azurerm_databricks_workspace.ad_platform.workspace_url}"
}

output "resource_group_name" {
  description = "Resource group name (alias for ADE portal display)"
  value       = data.azurerm_resource_group.ad_platform.name
}

output "sql_server_fqdn" {
  description = "SQL Server fully qualified domain name — used by deploy.sh to run schema script"
  value       = azurerm_mssql_server.ad_platform.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "SQL Database name — used by deploy.sh to target the correct database"
  value       = azurerm_mssql_database.ad_platform.name
}
output "deployment_handoff" {
  description = "Non-secret values for phase 2; export only this object, not the full state."
  value = {
    prefix                = var.prefix
    workspace_url         = "https://${azurerm_databricks_workspace.ad_platform.workspace_url}"
    workspace_resource_id = azurerm_databricks_workspace.ad_platform.id
    workspace_id          = azurerm_databricks_workspace.ad_platform.workspace_id
    access_connector_id   = azurerm_databricks_access_connector.ad_platform.id
    storage_account_name  = azurerm_storage_account.ad_platform.name
  }
}
output "dns_resolver_inbound_ip" {
  value = azurerm_private_dns_resolver_inbound_endpoint.environment.ip_configurations[0].private_ip_address
}
output "application_identity_object_id" { value = azurerm_user_assigned_identity.application.principal_id }
