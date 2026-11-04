terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "prefix" {
  type        = string
  description = "Client and environment prefix, e.g. acme-dev1"
}

variable "resource_group_name" {
  type        = string
  description = "Target Azure Resource Group"
}

variable "region" {
  type        = string
  default     = "eastus2"
  description = "Azure region"
}

variable "storage_account_name" {
  type        = string
  description = "Unique Azure Storage Account name (lowercase alphanumeric 3-24 chars)"
}

variable "client_name" {
  type        = string
  default     = "client"
  description = "Client name for container partitioning"
}

# 1. Resource Group
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.region
  tags = {
    Environment = var.prefix
    ManagedBy   = "AD-Platform"
    Platform    = "Free-Trial-POC"
  }
}

# 2. ADLS Gen2 Storage Account (Zero-quota, free-trial safe)
resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true # Hierarchical Namespace for Unity Catalog / ADLS Gen2
  min_tls_version          = "TLS1_2"

  tags = {
    Environment = var.prefix
    ManagedBy   = "AD-Platform"
    Platform    = "Free-Trial-POC"
  }
}

# 3. Client Isolated Filesystem Container
resource "azurerm_storage_data_lake_gen2_filesystem" "client_container" {
  name               = "client-${lower(var.client_name)}"
  storage_account_id = azurerm_storage_account.this.id
}

output "resource_group_id" {
  value = azurerm_resource_group.this.id
}

output "storage_account_id" {
  value = azurerm_storage_account.this.id
}

output "storage_account_name" {
  value = azurerm_storage_account.this.name
}

output "container_name" {
  value = azurerm_storage_data_lake_gen2_filesystem.client_container.name
}
