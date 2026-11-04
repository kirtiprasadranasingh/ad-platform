variable "resource_group_name" {
  description = "(Required) Name of the resource group"
  type        = string
}

variable "name" {
  description = "(Required) Name of the private endpoint"
  type        = string
}

variable "location" {
  description = "(Required) Location (or region) of the private endpoint"
  type        = string
}

variable "subnet_id" {
  description = "(Required) Virtual network subnet id"
  type        = string
}

variable "private_dns" {
  description = <<-EOF
  (Required) Private dns zone config

  (Required) resource_id - Private dns zone resource id
  (Required) name - Private dns zone resource name
  (Required) a_name - Private dns zone resource a_name
  EOF

  type = map(string)
}

variable "private_link_enabled_resource_id" {
  description = "(Required) Private link enabled resource id"
  type        = string
}

variable "subresource_names" {
  description = "(Required) Subresource names"
  type        = list(string)
}

variable "log_analytics_workspace_id" {
  description = "(Required) Log analytics workspace id"
  type        = string
}
