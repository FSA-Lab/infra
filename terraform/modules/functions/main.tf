resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  min_tls_version          = var.min_tls_version
  tags                     = var.tags
}

resource "azurerm_servicebus_namespace" "this" {
  name                = var.servicebus_namespace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.servicebus_sku

  tags = var.tags
}

resource "azurerm_servicebus_queue" "this" {
  namespace_id         = azurerm_servicebus_namespace.this.id
  for_each             = toset(var.servicebus_queues)
  partitioning_enabled = true
  name                 = each.value
  dead_lettering_on_message_expiration = true
}

resource "azurerm_service_plan" "this" {
  os_type             = var.os_type
  location            = var.location
  name                = var.service_plan_name
  sku_name            = var.sku_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_linux_function_app" "this" {
  name                = var.function_app_name
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.this.id

  storage_account_name       = azurerm_storage_account.this.name
  storage_account_access_key = azurerm_storage_account.this.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  app_settings = merge({
    FUNCTIONS_WORKER_RUNTIME = var.worker_runtime
    WEBSITE_RUN_FROM_PACKAGE = var.run_from_package
  }, var.app_settings)

  tags = var.tags

  site_config {

  }
}
