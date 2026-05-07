resource "azurerm_resource_group" "this" {
  name     = var.FUNCTIONS_RESOURCE_GROUP_NAME
  location = var.FUNCTIONS_LOCATION

  tags = var.FUNCTIONS_TAGS
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.FUNCTIONS_LOG_ANALYTICS_WORKSPACE_NAME
  location            = var.FUNCTIONS_LOCATION
  resource_group_name = azurerm_resource_group.this.name
  sku                 = var.FUNCTIONS_LOG_ANALYTICS_SKU
  retention_in_days   = var.FUNCTIONS_LOG_ANALYTICS_RETENTION_DAYS

  tags = var.FUNCTIONS_TAGS
}

resource "azurerm_application_insights" "this" {
  name                = var.FUNCTIONS_APP_INSIGHTS_NAME
  location            = var.FUNCTIONS_LOCATION
  resource_group_name = azurerm_resource_group.this.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.this.id

  tags = var.FUNCTIONS_TAGS
}

resource "azurerm_storage_account" "this" {
  name                     = var.FUNCTIONS_STORAGE_ACCOUNT_NAME
  resource_group_name      = azurerm_resource_group.this.name
  location                 = var.FUNCTIONS_LOCATION
  account_tier             = var.FUNCTIONS_ACCOUNT_TIER
  account_replication_type = var.FUNCTIONS_ACCOUNT_REPLICATION_TYPE
  min_tls_version          = var.FUNCTIONS_MIN_TLS_VERSION
  tags                     = var.FUNCTIONS_TAGS

  depends_on = [ azurerm_resource_group.this ]
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
  partitioning_enabled = var.FUNCTIONS_SERVICEBUS_QUEUE_PARTITIONING_ENABLED
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

resource "azurerm_postgresql_flexible_server" "this" {
  name                          = var.FUNCTIONS_POSTGRES_SERVER_NAME
  location                      = var.FUNCTIONS_LOCATION
  resource_group_name           = azurerm_resource_group.this.name
  administrator_login           = var.FUNCTIONS_POSTGRES_ADMIN_LOGIN
  administrator_password        = var.FUNCTIONS_POSTGRES_ADMIN_PASSWORD
  version                       = var.FUNCTIONS_POSTGRES_VERSION
  sku_name                      = var.FUNCTIONS_POSTGRES_SKU_NAME
  storage_mb                    = var.FUNCTIONS_POSTGRES_STORAGE_MB
  backup_retention_days         = var.FUNCTIONS_POSTGRES_BACKUP_RETENTION_DAYS
  geo_redundant_backup_enabled  = var.FUNCTIONS_POSTGRES_GEO_REDUNDANT_BACKUP_ENABLED
  public_network_access_enabled = var.FUNCTIONS_POSTGRES_PUBLIC_NETWORK_ACCESS_ENABLED

  tags = var.FUNCTIONS_TAGS

  lifecycle {
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "this" {
  name      = var.FUNCTIONS_POSTGRES_DB_NAME
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = var.FUNCTIONS_POSTGRES_DB_CHARSET
  collation = var.FUNCTIONS_POSTGRES_DB_COLLATION
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  count    = var.FUNCTIONS_POSTGRES_ALLOW_AZURE_SERVICES ? 1 : 0
  name     = "allow-azure-services"
  server_id = azurerm_postgresql_flexible_server.this.id

  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "custom" {
  for_each = { for rule in var.FUNCTIONS_POSTGRES_FIREWALL_RULES : rule.name => rule }

  name      = each.value.name
  server_id = azurerm_postgresql_flexible_server.this.id

  start_ip_address = each.value.start_ip_address
  end_ip_address   = each.value.end_ip_address
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
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.this.connection_string
    POSTGRES_HOST     = azurerm_postgresql_flexible_server.this.fqdn
    POSTGRES_DB       = azurerm_postgresql_flexible_server_database.this.name
    POSTGRES_USER     = var.FUNCTIONS_POSTGRES_ADMIN_LOGIN
    POSTGRES_PASSWORD = var.FUNCTIONS_POSTGRES_ADMIN_PASSWORD
    POSTGRES_PORT     = "5432"
  }, var.FUNCTIONS_APP_SETTINGS)

  tags = var.FUNCTIONS_TAGS

  site_config {

  }

  lifecycle {
    ignore_changes = [
      site_config[0].application_insights_connection_string
    ]
  }
}

data "azurerm_monitor_diagnostic_categories" "function_app" {
  resource_id = azurerm_linux_function_app.this.id
}

resource "azurerm_monitor_diagnostic_setting" "function_app" {
  name                       = "diag-function-app"
  target_resource_id         = azurerm_linux_function_app.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.function_app.log_category_types
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = data.azurerm_monitor_diagnostic_categories.storage.metrics
    content {
      category = enabled_metric.value
    }
  }

  lifecycle {
    ignore_changes = [
      enabled_log,
      metric
    ]
  }
}

data "azurerm_monitor_diagnostic_categories" "storage" {
  resource_id = azurerm_storage_account.this.id
}

resource "azurerm_monitor_diagnostic_setting" "storage" {
  name                       = "diag-storage"
  target_resource_id         = azurerm_storage_account.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.storage.log_category_types
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = data.azurerm_monitor_diagnostic_categories.storage.metrics
    content {
      category = enabled_metric.value
    }
  }

  lifecycle {
    ignore_changes = [
      enabled_log,
      metric
    ]
  }
}

data "azurerm_monitor_diagnostic_categories" "servicebus" {
  resource_id = azurerm_servicebus_namespace.this.id
}

resource "azurerm_monitor_diagnostic_setting" "servicebus" {
  name                       = "diag-servicebus"
  target_resource_id         = azurerm_servicebus_namespace.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.servicebus.log_category_types
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = data.azurerm_monitor_diagnostic_categories.storage.metrics
    content {
      category = enabled_metric.value
    }
  }

  lifecycle {
    ignore_changes = [
      enabled_log,
      metric
    ]
  }
}

data "azurerm_monitor_diagnostic_categories" "postgres" {
  resource_id = azurerm_postgresql_flexible_server.this.id
}

resource "azurerm_monitor_diagnostic_setting" "postgres" {
  name                       = "diag-postgres"
  target_resource_id         = azurerm_postgresql_flexible_server.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.postgres.log_category_types
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = data.azurerm_monitor_diagnostic_categories.storage.metrics
    content {
      category = enabled_metric.value
    }
  }

  lifecycle {
    ignore_changes = [
      enabled_log,
      metric
    ]
  }
}
