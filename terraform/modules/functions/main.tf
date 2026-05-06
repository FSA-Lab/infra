resource "azurerm_resource_group" "this" {
  name     = var.FUNCTIONS_RESOURCE_GROUP_NAME
  location = var.FUNCTIONS_LOCATION

  tags = var.FUNCTIONS_TAGS
}

resource "azurerm_storage_account" "this" {
  name                     = var.FUNCTIONS_STORAGE_ACCOUNT_NAME
  resource_group_name      = var.FUNCTIONS_RESOURCE_GROUP_NAME
  location                 = var.FUNCTIONS_LOCATION
  account_tier             = var.FUNCTIONS_ACCOUNT_TIER
  account_replication_type = var.FUNCTIONS_ACCOUNT_REPLICATION_TYPE
  min_tls_version          = var.FUNCTIONS_MIN_TLS_VERSION
  tags                     = var.FUNCTIONS_TAGS
}

resource "azurerm_servicebus_namespace" "this" {
  name                = var.FUNCTIONS_SERVICEBUS_NAMESPACE_NAME
  location            = var.FUNCTIONS_LOCATION
  resource_group_name = var.FUNCTIONS_RESOURCE_GROUP_NAME
  sku                 = var.FUNCTIONS_SERVICEBUS_SKU

  tags = var.FUNCTIONS_TAGS
}

resource "azurerm_servicebus_queue" "this" {
  namespace_id         = azurerm_servicebus_namespace.this.id
  for_each             = toset(var.FUNCTIONS_SERVICEBUS_QUEUES)
  partitioning_enabled = true
  name                 = each.value
  dead_lettering_on_message_expiration = true
}

resource "azurerm_service_plan" "this" {
  os_type             = var.FUNCTIONS_OS_TYPE
  location            = var.FUNCTIONS_LOCATION
  name                = var.FUNCTIONS_SERVICE_PLAN_NAME
  sku_name            = var.FUNCTIONS_SKU_NAME
  resource_group_name = var.FUNCTIONS_RESOURCE_GROUP_NAME
}

resource "azurerm_linux_function_app" "this" {
  name                = var.FUNCTIONS_FUNCTION_APP_NAME
  location            = var.FUNCTIONS_LOCATION
  resource_group_name = var.FUNCTIONS_RESOURCE_GROUP_NAME
  service_plan_id     = azurerm_service_plan.this.id

  storage_account_name       = azurerm_storage_account.this.name
  storage_account_access_key = azurerm_storage_account.this.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  app_settings = merge({
    FUNCTIONS_WORKER_RUNTIME = var.FUNCTIONS_WORKER_RUNTIME
    WEBSITE_RUN_FROM_PACKAGE = var.FUNCTIONS_RUN_FROM_PACKAGE
  }, var.FUNCTIONS_APP_SETTINGS)

  tags = var.FUNCTIONS_TAGS

  site_config {

  }
}
