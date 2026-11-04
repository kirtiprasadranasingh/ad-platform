resource "azurerm_storage_container" "data-stage" {
  name                  = "data-stage"
  storage_account_id    = azurerm_storage_account.ad_platform.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "store" {
  name                  = "store"
  storage_account_id    = azurerm_storage_account.ad_platform.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "adenv-logs" {
  name                  = "adenv-logs"
  storage_account_id    = azurerm_storage_account.ad_platform.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "backups" {
  name                  = "backups"
  storage_account_id    = azurerm_storage_account.ad_platform.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "metastore-files" {
  name                  = "metastore-files"
  storage_account_id    = azurerm_storage_account.ad_platform.id
  container_access_type = "private"
}
