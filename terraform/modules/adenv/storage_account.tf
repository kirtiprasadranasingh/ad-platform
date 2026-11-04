resource "azurerm_storage_account" "ad_platform" {
  name                              = var.storage_account_name
  location                          = var.region
  resource_group_name               = data.azurerm_resource_group.ad_platform.name
  account_replication_type          = "LRS"
  account_tier                      = "Premium"
  account_kind                      = "BlockBlobStorage"
  is_hns_enabled                    = true
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  public_network_access_enabled     = false
  allow_nested_items_to_be_public   = false
  shared_access_key_enabled         = false
  infrastructure_encryption_enabled = true
  lifecycle { prevent_destroy = true }
  blob_properties {
    delete_retention_policy { days = 30 }
    container_delete_retention_policy { days = 30 }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["None"]
  }

  tags = {
    client      = var.client_name
    environment = var.env_name
    managed_by  = "terraform"
  }

  timeouts {
    create = "60m"
    read   = "30m"
    update = "60m"
    delete = "60m"
  }
}

module "diagnostic_setting" {
  source                     = "../shared/diagnostic_setting"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.ad_platform.id
  resource_id                = azurerm_storage_account.ad_platform.id
  resource_name              = azurerm_storage_account.ad_platform.name
}

module "storage_container_private_endpoint" {
  source = "../shared/private_endpoint"

  resource_group_name = data.azurerm_resource_group.ad_platform.name
  name                = azurerm_storage_account.ad_platform.name
  location            = var.region
  subnet_id           = azurerm_subnet.storage_account.id

  private_dns = {
    resource_id = azurerm_private_dns_zone.storage_account.id
    name        = azurerm_private_dns_zone.storage_account.name
    a_name      = "dns-${var.prefix}-sa"
  }

  private_link_enabled_resource_id = azurerm_storage_account.ad_platform.id
  subresource_names                = ["blob"]
  log_analytics_workspace_id       = azurerm_log_analytics_workspace.ad_platform.id
  depends_on                       = [azurerm_subnet.storage_account]
}

module "storage_container_private_endpoint_dfs" {
  source = "../shared/private_endpoint"

  resource_group_name = data.azurerm_resource_group.ad_platform.name
  name                = "${azurerm_storage_account.ad_platform.name}-dfs"
  location            = var.region
  subnet_id           = azurerm_subnet.storage_account.id

  private_dns = {
    resource_id = azurerm_private_dns_zone.storage_account_dfs.id
    name        = azurerm_private_dns_zone.storage_account_dfs.name
    a_name      = "dns-${var.prefix}-sa-dfs"
  }

  private_link_enabled_resource_id = azurerm_storage_account.ad_platform.id
  subresource_names                = ["dfs"]
  log_analytics_workspace_id       = azurerm_log_analytics_workspace.ad_platform.id
  depends_on                       = [module.storage_container_private_endpoint]
}
