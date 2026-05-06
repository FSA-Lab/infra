
variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "storage_account_name" {
  type = string
}

variable "account_replication_type" {
  type = string
}

variable "service_plan_name" {
  type = string
}

variable "function_app_name" {
  type = string
}

variable "worker_runtime" {
  type = string
}

variable "run_from_package" {
  type = string
}

variable "app_settings" {
  type = map(string)
}

variable "tags" {
  type = map(string)
}

variable "servicebus_namespace_name" {
  type = string
}

variable "servicebus_queues" {
  type = list(string)
}

variable "servicebus_sku" {
  type = string
}

variable "os_type" {
  type = string
}

variable "sku_name" {
  type = string
}

variable "account_tier" {
  type = string
}

variable "min_tls_version" {
  type = string
}