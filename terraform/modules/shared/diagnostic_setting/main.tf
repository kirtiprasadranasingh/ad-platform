data "azurerm_monitor_diagnostic_categories" "main" {
  resource_id = var.resource_id
}

locals {
  raw_log_categories    = try(data.azurerm_monitor_diagnostic_categories.main.log_category_types, [])
  raw_metric_categories = try(data.azurerm_monitor_diagnostic_categories.main.metrics, [])

  log_categories    = toset(local.raw_log_categories)
  metric_categories = toset(local.raw_metric_categories)
}

resource "azurerm_monitor_diagnostic_setting" "main" {
  name                       = "${var.resource_name}-diagnostic-setting"
  target_resource_id         = var.resource_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = local.log_categories
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = local.metric_categories
    content {
      category = metric.value
      retention_policy {
        enabled = false
      }
    }
  }

}
