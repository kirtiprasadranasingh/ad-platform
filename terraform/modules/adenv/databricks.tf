resource "azurerm_databricks_workspace" "ad_platform" {
  name                                  = "dbw-${var.prefix}"
  resource_group_name                   = data.azurerm_resource_group.ad_platform.name
  location                              = var.region
  sku                                   = "premium"
  public_network_access_enabled         = false
  network_security_group_rules_required = "NoAzureDatabricksRules"
  infrastructure_encryption_enabled     = true
  enhanced_security_compliance {
    automatic_cluster_update_enabled      = true
    enhanced_security_monitoring_enabled  = true
    compliance_security_profile_enabled   = true
    compliance_security_profile_standards = ["HIPAA"]
  }
  lifecycle { prevent_destroy = true }

  custom_parameters {
    no_public_ip                                         = true
    public_subnet_name                                   = azurerm_subnet.databricks_public.name
    private_subnet_name                                  = azurerm_subnet.databricks_private.name
    virtual_network_id                                   = azurerm_virtual_network.ad_platform.id
    public_subnet_network_security_group_association_id  = azurerm_subnet_network_security_group_association.databricks_public.id
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.databricks_private.id
  }

  tags = {
    client      = var.client_name
    environment = var.env_name
    managed_by  = "terraform"
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.databricks_public,
    azurerm_subnet_network_security_group_association.databricks_private
  ]
}

module "databricks_diagnostic_setting" {
  source                     = "../shared/diagnostic_setting"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.ad_platform.id
  resource_id                = azurerm_databricks_workspace.ad_platform.id
  resource_name              = azurerm_databricks_workspace.ad_platform.name
}

resource "azurerm_databricks_access_connector" "ad_platform" {
  name                = "dbc-${var.prefix}"
  resource_group_name = data.azurerm_resource_group.ad_platform.name
  location            = var.region

  identity {
    type = "SystemAssigned"
  }

  tags = {
    client      = var.client_name
    environment = var.env_name
    managed_by  = "terraform"
  }


}
