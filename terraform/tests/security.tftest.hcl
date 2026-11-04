mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = {
      name     = "rg-synthetic"
      location = "canadacentral"
      id       = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-synthetic"
    }
  }
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "11111111-1111-1111-1111-111111111111"
      object_id = "22222222-2222-2222-2222-222222222222"
    }
  }
}
mock_provider "random" {}

variables {
  client_name                   = "synthetic"
  env_name                      = "test"
  prefix                        = "synthetic-test"
  storage_account_name          = "synthetictestdata"
  resource_group_name           = "rg-synthetic"
  region                        = "canadacentral"
  tenant_id                     = "11111111-1111-1111-1111-111111111111"
  subscription_id               = "11111111-1111-1111-1111-111111111111"
  deployment_identity_client_id = "22222222-2222-2222-2222-222222222222"
  sql_admin_group_object_id     = "33333333-3333-3333-3333-333333333333"
  vnet_cidr                     = "10.60.0.0/16,10.61.0.0/16"
  approved_client_cidrs         = ["10.62.0.0/24"]
  approved_egress_fqdns         = ["login.microsoftonline.com"]
  application_image             = "api@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  application_registry_id       = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-platform/providers/Microsoft.ContainerRegistry/registries/syntheticregistry"
  application_registry_host     = "syntheticregistry.azurecr.io"
  entra_application_client_id   = "44444444-4444-4444-4444-444444444444"
  authentication_vault_id       = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-platform/providers/Microsoft.KeyVault/vaults/synthetic-auth"
  authentication_secret_uri     = "https://synthetic-auth.vault.azure.net/secrets/app-auth"
}

run "secure_resource_graph" {
  command = plan
  assert {
    condition     = module.adenv.security_contract.segment_count == 7
    error_message = "Every workload subnet must have a separate NSG."
  }
  assert {
    condition     = module.adenv.security_contract.routed_subnet_count == 7
    error_message = "Every workload subnet must route egress through the firewall."
  }
  assert {
    condition     = module.adenv.security_contract.private_app && module.adenv.security_contract.entra_only_sql
    error_message = "Private application and Entra-only database controls must be retained."
  }
}

run "reject_mutable_image" {
  command = plan
  variables { application_image = "api:latest" }
  expect_failures = [var.application_image]
}

run "reject_overlapping_networks" {
  command = plan
  variables { vnet_cidr = "10.60.0.0/16,10.60.0.0/16" }
  expect_failures = [var.vnet_cidr]
}

run "reject_public_networks" {
  command = plan
  variables { vnet_cidr = "8.8.0.0/16,10.60.0.0/16" }
  expect_failures = [var.vnet_cidr]
}

run "reject_wildcard_egress" {
  command = plan
  variables { approved_egress_fqdns = ["*"] }
  expect_failures = [var.approved_egress_fqdns]
}
