variable "application_image" {
  description = "Approved repository@sha256:digest already published in the private application registry."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9/_.-]*@sha256:[a-f0-9]{64}$", var.application_image))
    error_message = "An immutable image digest is required; mutable tags are forbidden."
  }
}
variable "application_registry_id" {
  type        = string
  description = "Existing private registry resource ID holding the approved application image."
}
variable "application_registry_host" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9]+\\.azurecr\\.io$", var.application_registry_host))
    error_message = "Use an Azure Container Registry hostname without a scheme or path."
  }
}
variable "entra_application_client_id" {
  type        = string
  description = "Client-owned single-tenant app registration with explicit user/group assignment."
}
variable "authentication_vault_id" {
  type        = string
  description = "Existing private Key Vault holding the Easy Auth credential, with client-owned rotation."
}
variable "authentication_secret_uri" {
  type        = string
  description = "Versionless URI, not the secret VALUE. App Service resolves this using its managed identity."
  validation {
    condition     = can(regex("^https://[a-zA-Z0-9-]+\\.vault\\.azure\\.net/secrets/[a-zA-Z0-9-]+$", var.authentication_secret_uri))
    error_message = "A versionless Azure Key Vault secret URI is required."
  }
}
variable "approved_client_cidrs" {
  description = "Private runner/VPN source CIDRs permitted to reach application and data private endpoints."
  type        = list(string)
  validation {
    condition     = length(var.approved_client_cidrs) > 0 && alltrue([for c in var.approved_client_cidrs : can(cidrnetmask(c)) && !endswith(c, "/0")])
    error_message = "Supply explicit IPv4 client CIDRs; unrestricted source ranges are forbidden."
  }
}
variable "approved_egress_fqdns" {
  description = "Explicit approved service/package FQDNs for HTTPS egress. Empty means no internet egress."
  type        = set(string)
  default     = []
  validation {
    condition     = alltrue([for h in var.approved_egress_fqdns : can(regex("^[a-zA-Z0-9][a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", h)) && !strcontains(h, "*")])
    error_message = "Use exact FQDNs, not wildcards, URLs or IP addresses."
  }
}
