output "function_app_id" {
  value = azurerm_linux_function_app.this.id
}

output "function_app_default_hostname" {
  value = azurerm_linux_function_app.this.default_hostname
}
