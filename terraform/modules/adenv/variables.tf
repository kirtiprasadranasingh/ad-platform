variable "client_name" {
  description = "Short client identifier (e.g. apple, disney). Drives tagging."
  type        = string
}

variable "env_name" {
  description = "Environment label (e.g. dev1, qa1, prod). Drives tagging."
  type        = string
}

variable "prefix" {
  description = "Combined naming prefix: '{client_name}-{env_name}'."
  type        = string
}

variable "storage_account_name" {
  description = "Storage account name — pre-computed by deploy.sh to enforce 24-char Azure limit."
  type        = string
}

variable "region" {
  description = "Azure region for all resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name. Always derived as 'rg-{client}-{env}'."
  type        = string
}



variable "tenant_id" {
  description = "Azure AD tenant ID."
  type        = string
}





variable "sql" {
  description = "SQL Server configuration."
  type = object({
    version             = string
    minimum_tls_version = string
  })
}



variable "network" {
  description = "Network configuration."
  type = object({
    vnet_address_space = list(string)
    subnet_address_space = object({
      cidr_1 = list(string)
      cidr_2 = list(string)
      cidr_3 = list(string)
      cidr_4 = list(string)
      cidr_5 = list(string)
      cidr_6 = list(string)
      databricks = object({
        cidr_1 = list(string)
        cidr_2 = list(string)
      })
    })
  })
}

variable "keyvault" {
  description = "Key Vault configuration."
  type = object({
    sku_name = string
  })
  default = {
    sku_name = "standard"
  }
}

variable "log_analytics" {
  description = "Log Analytics workspace configuration."
  type = object({
    retentions_in_days = number
  })
}




variable "sql_admin_group_object_id" {
  description = "Object ID of a restricted Entra SQL administrator group; members governed by PIM/MFA and access reviews."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.sql_admin_group_object_id))
    error_message = "A valid Entra group object UUID is required."
  }
}
