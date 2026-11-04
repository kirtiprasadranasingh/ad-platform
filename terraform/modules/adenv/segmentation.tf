locals {
  segment_prefixes = {
    storage_account    = var.network.subnet_address_space.cidr_2
    sql                = var.network.subnet_address_space.cidr_3
    keyvault           = var.network.subnet_address_space.cidr_4
    adplatformapi      = var.network.subnet_address_space.cidr_5
    container_registry = var.network.subnet_address_space.cidr_6
    databricks_public  = var.network.subnet_address_space.databricks.cidr_1
    databricks_private = var.network.subnet_address_space.databricks.cidr_2
  }
  compute_sources = concat(var.network.subnet_address_space.databricks.cidr_1,
  var.network.subnet_address_space.databricks.cidr_2)
  endpoint_sources = concat(var.approved_client_cidrs, local.compute_sources,
  var.network.subnet_address_space.cidr_5)
}

resource "azurerm_network_security_rule" "approved_inbound" {
  for_each                     = local.segment_prefixes
  name                         = "approved-private-traffic"
  priority                     = 100
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_ranges      = startswith(each.key, "databricks") ? ["*"] : each.key == "sql" ? ["1433"] : ["443"]
  source_address_prefixes      = startswith(each.key, "databricks") ? local.compute_sources : local.endpoint_sources
  destination_address_prefixes = each.value
  resource_group_name          = data.azurerm_resource_group.ad_platform.name
  network_security_group_name  = azurerm_network_security_group.ad_platform[each.key].name
}

resource "azurerm_network_security_rule" "deny_other_inbound" {
  for_each                    = local.segment_prefixes
  name                        = "deny-other-inbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.ad_platform.name
  network_security_group_name = azurerm_network_security_group.ad_platform[each.key].name
}

# HTTPS egress remains filtered by the mandatory firewall route; this is not
# direct internet permission. NSGs evaluate original destinations, not next hops.
resource "azurerm_network_security_rule" "https_egress" {
  for_each                    = local.segment_prefixes
  name                        = "https-through-firewall"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = each.value
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.ad_platform.name
  network_security_group_name = azurerm_network_security_group.ad_platform[each.key].name
}

resource "azurerm_network_security_rule" "private_sql" {
  for_each                     = local.segment_prefixes
  name                         = "private-sql"
  priority                     = 110
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "1433"
  source_address_prefixes      = each.value
  destination_address_prefixes = var.network.subnet_address_space.cidr_3
  resource_group_name          = data.azurerm_resource_group.ad_platform.name
  network_security_group_name  = azurerm_network_security_group.ad_platform[each.key].name
}

resource "azurerm_network_security_rule" "compute_internal" {
  for_each                     = { for k, v in local.segment_prefixes : k => v if startswith(k, "databricks") }
  name                         = "cluster-internal"
  priority                     = 120
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_range       = "*"
  source_address_prefixes      = each.value
  destination_address_prefixes = local.compute_sources
  resource_group_name          = data.azurerm_resource_group.ad_platform.name
  network_security_group_name  = azurerm_network_security_group.ad_platform[each.key].name
}

resource "azurerm_network_security_rule" "azure_dns" {
  for_each                    = local.segment_prefixes
  name                        = "azure-dns-only"
  priority                    = 130
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefixes     = each.value
  destination_address_prefix  = "AzurePlatformDNS"
  resource_group_name         = data.azurerm_resource_group.ad_platform.name
  network_security_group_name = azurerm_network_security_group.ad_platform[each.key].name
}

resource "azurerm_network_security_rule" "deny_other_outbound" {
  for_each                    = local.segment_prefixes
  name                        = "deny-other-outbound"
  priority                    = 4000
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.ad_platform.name
  network_security_group_name = azurerm_network_security_group.ad_platform[each.key].name
}

# Required Private Link control-plane ports, restricted to this workspace's PE.
# https://learn.microsoft.com/azure/databricks/security/network/concepts/private-link
resource "azurerm_network_security_rule" "databricks_private_link_in" {
  name                        = "databricks-private-control"
  priority                    = 150
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["443", "6666", "3306", "8443-8451"]
  source_address_prefixes     = local.compute_sources
  destination_address_prefix  = azurerm_private_endpoint.databricks_ui_api.private_service_connection[0].private_ip_address
  resource_group_name         = data.azurerm_resource_group.ad_platform.name
  network_security_group_name = azurerm_network_security_group.ad_platform["container_registry"].name
}

resource "azurerm_network_security_rule" "databricks_private_link_out" {
  for_each                    = { for k, v in local.segment_prefixes : k => v if startswith(k, "databricks") }
  name                        = "databricks-private-control"
  priority                    = 150
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["443", "6666", "3306", "8443-8451"]
  source_address_prefixes     = each.value
  destination_address_prefix  = azurerm_private_endpoint.databricks_ui_api.private_service_connection[0].private_ip_address
  resource_group_name         = data.azurerm_resource_group.ad_platform.name
  network_security_group_name = azurerm_network_security_group.ad_platform[each.key].name
}

resource "azurerm_network_security_rule" "managed_identity_metadata" {
  for_each                    = local.segment_prefixes
  name                        = "managed-identity-metadata"
  priority                    = 140
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefixes     = each.value
  destination_address_prefix  = "AzurePlatformIMDS"
  resource_group_name         = data.azurerm_resource_group.ad_platform.name
  network_security_group_name = azurerm_network_security_group.ad_platform[each.key].name
}
