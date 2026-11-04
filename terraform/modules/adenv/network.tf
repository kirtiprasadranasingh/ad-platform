resource "azurerm_virtual_network" "ad_platform" {
  name                = "vnet-${var.prefix}"
  location            = var.region
  resource_group_name = data.azurerm_resource_group.ad_platform.name
  address_space       = var.network.vnet_address_space

  tags = {
    client      = var.client_name
    environment = var.env_name
    managed_by  = "terraform"
  }
}

module "vnet_diagnostic_setting" {
  source                     = "../shared/diagnostic_setting"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.ad_platform.id
  resource_id                = azurerm_virtual_network.ad_platform.id
  resource_name              = azurerm_virtual_network.ad_platform.name
}

resource "azurerm_subnet" "storage_account" {
  private_endpoint_network_policies = "NetworkSecurityGroupEnabled"
  name                              = "${var.prefix}-storage-account-subnet"
  resource_group_name               = data.azurerm_resource_group.ad_platform.name
  virtual_network_name              = azurerm_virtual_network.ad_platform.name
  address_prefixes                  = var.network.subnet_address_space.cidr_2
  depends_on                        = [azurerm_virtual_network.ad_platform]
}

resource "azurerm_subnet" "sql" {
  private_endpoint_network_policies = "NetworkSecurityGroupEnabled"
  name                              = "${var.prefix}-sql-subnet"
  resource_group_name               = data.azurerm_resource_group.ad_platform.name
  virtual_network_name              = azurerm_virtual_network.ad_platform.name
  address_prefixes                  = var.network.subnet_address_space.cidr_3

  depends_on = [azurerm_virtual_network.ad_platform, azurerm_subnet.storage_account]
}

resource "azurerm_subnet" "keyvault" {
  private_endpoint_network_policies = "NetworkSecurityGroupEnabled"
  name                              = "${var.prefix}-keyvault-subnet"
  resource_group_name               = data.azurerm_resource_group.ad_platform.name
  virtual_network_name              = azurerm_virtual_network.ad_platform.name
  address_prefixes                  = var.network.subnet_address_space.cidr_4
  depends_on                        = [azurerm_virtual_network.ad_platform, azurerm_subnet.sql]
}

resource "azurerm_subnet" "adplatformapi" {
  name                 = "${var.prefix}-adplatformapi-subnet"
  resource_group_name  = data.azurerm_resource_group.ad_platform.name
  virtual_network_name = azurerm_virtual_network.ad_platform.name
  address_prefixes     = var.network.subnet_address_space.cidr_5

  delegation {
    name = "delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
    }
  }

  depends_on = [azurerm_virtual_network.ad_platform, azurerm_subnet.keyvault]
}

resource "azurerm_subnet" "container_registry" {
  private_endpoint_network_policies = "NetworkSecurityGroupEnabled"
  name                              = "${var.prefix}-acr-subnet"
  resource_group_name               = data.azurerm_resource_group.ad_platform.name
  virtual_network_name              = azurerm_virtual_network.ad_platform.name
  address_prefixes                  = var.network.subnet_address_space.cidr_6
  depends_on                        = [azurerm_virtual_network.ad_platform, azurerm_subnet.adplatformapi]
}

resource "azurerm_subnet" "databricks_public" {
  name                 = "${var.prefix}-databricks-public-subnet"
  resource_group_name  = data.azurerm_resource_group.ad_platform.name
  virtual_network_name = azurerm_virtual_network.ad_platform.name
  address_prefixes     = var.network.subnet_address_space.databricks.cidr_1

  delegation {
    name = "databricks-delegation"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }
}

resource "azurerm_subnet" "databricks_private" {
  name                 = "${var.prefix}-databricks-private-subnet"
  resource_group_name  = data.azurerm_resource_group.ad_platform.name
  virtual_network_name = azurerm_virtual_network.ad_platform.name
  address_prefixes     = var.network.subnet_address_space.databricks.cidr_2

  delegation {
    name = "databricks-delegation"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

resource "azurerm_private_dns_zone" "storage_account" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.azurerm_resource_group.ad_platform.name
}

resource "azurerm_private_dns_zone" "storage_account_dfs" {
  name                = "privatelink.dfs.core.windows.net"
  resource_group_name = data.azurerm_resource_group.ad_platform.name
}

resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = data.azurerm_resource_group.ad_platform.name
}

resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = data.azurerm_resource_group.ad_platform.name
}

resource "azurerm_private_dns_zone" "container_registry" {
  name                = "privatelink.azurecr.io"
  resource_group_name = data.azurerm_resource_group.ad_platform.name
}

resource "azurerm_network_security_group" "ad_platform" {
  for_each            = local.segment_prefixes
  name                = "nsg-${var.prefix}-${each.key}"
  location            = var.region
  resource_group_name = data.azurerm_resource_group.ad_platform.name

  tags = {
    client      = var.client_name
    environment = var.env_name
    managed_by  = "terraform"
  }
}

module "network_security_group_diagnostic_setting" {
  for_each                   = azurerm_network_security_group.ad_platform
  source                     = "../shared/diagnostic_setting"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.ad_platform.id
  resource_id                = each.value.id
  resource_name              = each.value.name
}

resource "azurerm_subnet_network_security_group_association" "storage_account" {
  network_security_group_id = azurerm_network_security_group.ad_platform["storage_account"].id
  subnet_id                 = azurerm_subnet.storage_account.id
}

resource "azurerm_subnet_network_security_group_association" "sql" {
  network_security_group_id = azurerm_network_security_group.ad_platform["sql"].id
  subnet_id                 = azurerm_subnet.sql.id
}

resource "azurerm_subnet_network_security_group_association" "keyvault" {
  network_security_group_id = azurerm_network_security_group.ad_platform["keyvault"].id
  subnet_id                 = azurerm_subnet.keyvault.id
}

resource "azurerm_subnet_network_security_group_association" "adplatformapi" {
  network_security_group_id = azurerm_network_security_group.ad_platform["adplatformapi"].id
  subnet_id                 = azurerm_subnet.adplatformapi.id
}

resource "azurerm_subnet_network_security_group_association" "container_registry" {
  network_security_group_id = azurerm_network_security_group.ad_platform["container_registry"].id
  subnet_id                 = azurerm_subnet.container_registry.id
}

resource "azurerm_subnet_network_security_group_association" "databricks_public" {
  network_security_group_id = azurerm_network_security_group.ad_platform["databricks_public"].id
  subnet_id                 = azurerm_subnet.databricks_public.id
}

resource "azurerm_subnet_network_security_group_association" "databricks_private" {
  network_security_group_id = azurerm_network_security_group.ad_platform["databricks_private"].id
  subnet_id                 = azurerm_subnet.databricks_private.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_account" {
  name                  = "${var.prefix}-sa-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.storage_account.name
  resource_group_name   = data.azurerm_resource_group.ad_platform.name
  virtual_network_id    = azurerm_virtual_network.ad_platform.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_account_dfs" {
  name                  = "${var.prefix}-sa-dfs-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.storage_account_dfs.name
  resource_group_name   = data.azurerm_resource_group.ad_platform.name
  virtual_network_id    = azurerm_virtual_network.ad_platform.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = "${var.prefix}-sql-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  resource_group_name   = data.azurerm_resource_group.ad_platform.name
  virtual_network_id    = azurerm_virtual_network.ad_platform.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "${var.prefix}-kv-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  resource_group_name   = data.azurerm_resource_group.ad_platform.name
  virtual_network_id    = azurerm_virtual_network.ad_platform.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "container_registry" {
  name                  = "${var.prefix}-acr-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.container_registry.name
  resource_group_name   = data.azurerm_resource_group.ad_platform.name
  virtual_network_id    = azurerm_virtual_network.ad_platform.id
}
