output "function_app_id" {
  value = azurerm_linux_function_app.this.id
}

output "function_app_default_hostname" {
  value = azurerm_linux_function_app.this.default_hostname
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.this.id
}

output "application_insights_id" {
  value = azurerm_application_insights.this.id
}

output "postgres_server_fqdn" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}

output "postgres_database_name" {
  value = azurerm_postgresql_flexible_server_database.this.name
}
