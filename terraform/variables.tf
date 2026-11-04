variable "client_name" {
  type        = string
  description = "Short client identifier (e.g. disney, rbtest)."
}

variable "env_name" {
  type        = string
  description = "Environment label (e.g. dev1, qa2, prod)."
}

variable "prefix" {
  type        = string
  description = "Combined: '{client_name}-{env_name}'. Passed by deploy.sh."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,15}$", var.prefix))
    error_message = "Use a 3-16 character lowercase resource prefix; no PHI in names."
  }
}

variable "storage_account_name" {
  type        = string
  description = "Pre-computed SA name from deploy.sh — enforces 24-char Azure limit."
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage names must be 3-24 lowercase alphanumeric characters."
  }
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID."
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group: rg-{client}-{env}."
}





variable "vnet_cidr" {
  type        = string
  description = "Two distinct canonical private /16 IPv4 networks: general,Databricks. Allocated by client IPAM."
  validation {
    condition = try(length(split(",", var.vnet_cidr)) == 2 && length(distinct([for c in split(",", var.vnet_cidr) : trimspace(c)])) == 2 && alltrue([
      for c in split(",", var.vnet_cidr) : endswith(trimspace(c), "/16") &&
      cidrhost(trimspace(c), 0) == split("/", trimspace(c))[0] &&
      can(regex("^(10\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|192\\.168\\.)", trimspace(c)))
    ]), false)
    error_message = "Provide two non-overlapping canonical RFC1918 /16 networks, separated by a comma."
  }
}






variable "region" {
  description = "Region approved by the data-residency and service-availability review."
  type        = string
}

variable "sql_admin_group_object_id" {
  description = "Object ID of a restricted Entra SQL administrator group; members governed by PIM/MFA and access reviews."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.sql_admin_group_object_id))
    error_message = "A valid Entra group object UUID is required."
  }
}
