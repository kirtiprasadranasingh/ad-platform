# The firewall has a public egress IP, but workloads and private endpoints do not.
# No DNAT or inbound internet rule is configured.
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = data.azurerm_resource_group.ad_platform.name
  virtual_network_name = azurerm_virtual_network.ad_platform.name
  address_prefixes     = [cidrsubnet(var.network.vnet_address_space[0], 8, 7)]
}

resource "azurerm_public_ip" "firewall" {
  name                = "pip-${var.prefix}-egress"
  location            = var.region
  resource_group_name = data.azurerm_resource_group.ad_platform.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall_policy" "egress" {
  name                     = "fwpolicy-${var.prefix}"
  location                 = var.region
  resource_group_name      = data.azurerm_resource_group.ad_platform.name
  sku                      = "Premium"
  threat_intelligence_mode = "Deny"
  intrusion_detection { mode = "Deny" }
  dns { proxy_enabled = true }
}

resource "azurerm_firewall" "egress" {
  name                = "fw-${var.prefix}"
  location            = var.region
  resource_group_name = data.azurerm_resource_group.ad_platform.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Premium"
  firewall_policy_id  = azurerm_firewall_policy.egress.id
  ip_configuration {
    name                 = "egress"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "approved_https" {
  count              = length(var.approved_egress_fqdns) > 0 ? 1 : 0
  name               = "approved-workload-https"
  firewall_policy_id = azurerm_firewall_policy.egress.id
  priority           = 200
  application_rule_collection {
    name     = "explicit-https-destinations"
    priority = 200
    action   = "Allow"
    rule {
      name = "approved-service-hosts"
      source_addresses = concat(var.network.subnet_address_space.cidr_5,
        var.network.subnet_address_space.databricks.cidr_1,
      var.network.subnet_address_space.databricks.cidr_2)
      destination_fqdns = sort(tolist(var.approved_egress_fqdns))
      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

locals {
  routed_subnets = {
    storage_account    = azurerm_subnet.storage_account.id
    sql                = azurerm_subnet.sql.id
    keyvault           = azurerm_subnet.keyvault.id
    adplatformapi      = azurerm_subnet.adplatformapi.id
    container_registry = azurerm_subnet.container_registry.id
    databricks_public  = azurerm_subnet.databricks_public.id
    databricks_private = azurerm_subnet.databricks_private.id
  }
}

resource "azurerm_route_table" "workload" {
  name                          = "rt-${var.prefix}-egress"
  location                      = var.region
  resource_group_name           = data.azurerm_resource_group.ad_platform.name
  bgp_route_propagation_enabled = false
  route {
    name                   = "inspect-internet"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.egress.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "workload" {
  for_each       = local.routed_subnets
  subnet_id      = each.value
  route_table_id = azurerm_route_table.workload.id
}

resource "azurerm_subnet" "resolver" {
  name                 = "snet-${var.prefix}-dns-inbound"
  resource_group_name  = data.azurerm_resource_group.ad_platform.name
  virtual_network_name = azurerm_virtual_network.ad_platform.name
  address_prefixes     = [cidrsubnet(var.network.vnet_address_space[0], 8, 8)]
  delegation {
    name = "dns-resolver"
    service_delegation {
      name    = "Microsoft.Network/dnsResolvers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_resolver" "environment" {
  name                = "dns-${var.prefix}"
  location            = var.region
  resource_group_name = data.azurerm_resource_group.ad_platform.name
  virtual_network_id  = azurerm_virtual_network.ad_platform.id
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "environment" {
  name                    = "inbound"
  private_dns_resolver_id = azurerm_private_dns_resolver.environment.id
  location                = var.region
  ip_configurations {
    private_ip_allocation_method = "Dynamic"
    subnet_id                    = azurerm_subnet.resolver.id
  }
}

module "firewall_diagnostics" {
  source                     = "../shared/diagnostic_setting"
  resource_id                = azurerm_firewall.egress.id
  resource_name              = azurerm_firewall.egress.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.ad_platform.id
}
