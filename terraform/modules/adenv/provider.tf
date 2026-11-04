terraform {
  required_version = ">= 1.14.0, < 2.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 4.81.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.9.0"
    }
  }
}
# Azure provider inherited from the root; no embedded credentials or Graph writes.
