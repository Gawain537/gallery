data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = "rg-${var.environment}"
  tags     = local.default_tags
}

resource "azurerm_storage_account" "storage_account" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.default_tags

  name = "sa${var.environment}"

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled = false
  shared_access_key_enabled     = true

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_storage_account_static_website" "static_website" {
  storage_account_id = azurerm_storage_account.storage_account.id
  index_document = "index.html"
}


resource "azurerm_static_web_app" "main" {
  name                = "swa-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.default_tags
  # SKU - Free or Standard
  sku_tier = "Free"
  sku_size = "Free"

  lifecycle {
    ignore_changes = [
      repository_url,
      repository_branch,
    ]
  }
}