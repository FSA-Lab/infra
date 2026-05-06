
variable "FUNCTIONS_RESOURCE_GROUP_NAME" {
  type = string
}

variable "FUNCTIONS_LOCATION" {
  type = string
}

variable "FUNCTIONS_STORAGE_ACCOUNT_NAME" {
  type = string
}

variable "FUNCTIONS_ACCOUNT_REPLICATION_TYPE" {
  type = string
}

variable "FUNCTIONS_SERVICE_PLAN_NAME" {
  type = string
}

variable "FUNCTIONS_FUNCTION_APP_NAME" {
  type = string
}

variable "FUNCTIONS_WORKER_RUNTIME" {
  type = string
}

variable "FUNCTIONS_RUN_FROM_PACKAGE" {
  type = string
}

variable "FUNCTIONS_APP_SETTINGS" {
  type = map(string)
}

variable "FUNCTIONS_TAGS" {
  type = map(string)
}

variable "FUNCTIONS_SERVICEBUS_NAMESPACE_NAME" {
  type = string
}

variable "FUNCTIONS_SERVICEBUS_QUEUES" {
  type = list(string)
}

variable "FUNCTIONS_SERVICEBUS_SKU" {
  type = string
}

variable "FUNCTIONS_SERVICEBUS_QUEUE_PARTITIONING_ENABLED" {
  type = bool
}

variable "FUNCTIONS_OS_TYPE" {
  type = string
}

variable "FUNCTIONS_SKU_NAME" {
  type = string
}

variable "FUNCTIONS_ACCOUNT_TIER" {
  type = string
}

variable "FUNCTIONS_MIN_TLS_VERSION" {
  type = string
}

variable "FUNCTIONS_LOG_ANALYTICS_WORKSPACE_NAME" {
  type = string
}

variable "FUNCTIONS_LOG_ANALYTICS_SKU" {
  type = string
}

variable "FUNCTIONS_LOG_ANALYTICS_RETENTION_DAYS" {
  type = number
}

variable "FUNCTIONS_APP_INSIGHTS_NAME" {
  type = string
}

variable "FUNCTIONS_POSTGRES_SERVER_NAME" {
  type = string
}

variable "FUNCTIONS_POSTGRES_VERSION" {
  type = string
}

variable "FUNCTIONS_POSTGRES_ADMIN_LOGIN" {
  type = string
}

variable "FUNCTIONS_POSTGRES_ADMIN_PASSWORD" {
  type      = string
  sensitive = true
}

variable "FUNCTIONS_POSTGRES_SKU_NAME" {
  type = string
}

variable "FUNCTIONS_POSTGRES_STORAGE_MB" {
  type = number
}

variable "FUNCTIONS_POSTGRES_BACKUP_RETENTION_DAYS" {
  type = number
}

variable "FUNCTIONS_POSTGRES_GEO_REDUNDANT_BACKUP_ENABLED" {
  type = bool
}

variable "FUNCTIONS_POSTGRES_PUBLIC_NETWORK_ACCESS_ENABLED" {
  type = bool
}

variable "FUNCTIONS_POSTGRES_DB_NAME" {
  type = string
}

variable "FUNCTIONS_POSTGRES_DB_CHARSET" {
  type = string
}

variable "FUNCTIONS_POSTGRES_DB_COLLATION" {
  type = string
}

variable "FUNCTIONS_POSTGRES_ALLOW_AZURE_SERVICES" {
  type = bool
}

variable "FUNCTIONS_POSTGRES_FIREWALL_RULES" {
  type = list(object({
    name             = string
    start_ip_address = string
    end_ip_address   = string
  }))
}