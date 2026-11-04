terraform {
  required_version = ">= 1.14.0, < 2.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 4.81.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
  storage_use_azuread = true
  use_msi             = true
  use_cli             = false
  client_id           = var.deployment_identity_client_id
  subscription_id     = var.subscription_id
  tenant_id           = var.tenant_id
}


locals {
  region = var.region


  vnet_cidrs      = split(",", var.vnet_cidr)
  general_cidr    = trimspace(local.vnet_cidrs[0])
  databricks_cidr = trimspace(local.vnet_cidrs[1])

}

module "adenv" {
  sql_admin_group_object_id   = var.sql_admin_group_object_id
  source                      = "./modules/adenv"
  application_image           = var.application_image
  application_registry_id     = var.application_registry_id
  application_registry_host   = var.application_registry_host
  entra_application_client_id = var.entra_application_client_id
  authentication_vault_id     = var.authentication_vault_id
  authentication_secret_uri   = var.authentication_secret_uri
  approved_client_cidrs       = var.approved_client_cidrs
  approved_egress_fqdns       = var.approved_egress_fqdns

  client_name          = var.client_name
  env_name             = var.env_name
  prefix               = var.prefix
  storage_account_name = var.storage_account_name
  resource_group_name  = var.resource_group_name
  region               = local.region


  tenant_id = var.tenant_id


  sql = {
    version             = "12.0"
    minimum_tls_version = "1.2"
  }



  network = {
    vnet_address_space = [local.general_cidr, local.databricks_cidr]
    subnet_address_space = {
      cidr_1 = [cidrsubnet(local.general_cidr, 8, 1)] # reserved / app subnet
      cidr_2 = [cidrsubnet(local.general_cidr, 8, 2)] # storage account subnet
      cidr_3 = [cidrsubnet(local.general_cidr, 8, 3)] # SQL subnet
      cidr_4 = [cidrsubnet(local.general_cidr, 8, 4)] # Key Vault subnet
      cidr_5 = [cidrsubnet(local.general_cidr, 8, 5)] # App Service subnet
      cidr_6 = [cidrsubnet(local.general_cidr, 8, 6)] # ACR subnet
      databricks = {
        cidr_1 = [cidrsubnet(local.databricks_cidr, 8, 1)] # Databricks public
        cidr_2 = [cidrsubnet(local.databricks_cidr, 8, 2)] # Databricks private
      }
    }
  }

  keyvault = {
    sku_name = "standard"
  }

  log_analytics = {
    retentions_in_days = 90
  }
}
