output "resource_group_name" {
  description = "Name of the deployed resource group — used by ADE portal 'View Resources'"
  value       = module.adenv.name
}

output "resource_group_id" {
  description = "Resource Group ID"
  value       = module.adenv.id
}

output "resource_group_location" {
  description = "Deployment region"
  value       = module.adenv.location
}

output "keyvault_endpoint" {
  description = "Key Vault vault URI — use in app configuration"
  value       = module.adenv.keyvault_endpoint
}

output "keyvault_id" {
  description = "Key Vault resource ID"
  value       = module.adenv.keyvault_id
}

output "blob_endpoint" {
  description = "Storage Account primary blob endpoint"
  value       = module.adenv.blob_endpoint
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for monitoring dashboards"
  value       = module.adenv.log_analytics_workspace_id
}

output "app_service_url" {
  description = "AD Platform API App Service URL"
  value       = module.adenv.app_service_url
}

output "databricks_workspace_url" {
  description = "Databricks workspace URL"
  value       = module.adenv.databricks_workspace_url
}

output "acr_dns_name" {
  description = "Container Registry private DNS zone name"
  value       = module.adenv.acr_dns_name
}
output "sql_server_fqdn" {
  description = "SQL Server fully qualified domain name"
  value       = module.adenv.sql_server_fqdn
}

output "sql_database_name" {
  description = "SQL Database name"
  value       = module.adenv.sql_database_name
}
output "deployment_handoff" { value = module.adenv.deployment_handoff }
output "dns_resolver_inbound_ip" { value = module.adenv.dns_resolver_inbound_ip }
output "application_identity_object_id" { value = module.adenv.application_identity_object_id }
