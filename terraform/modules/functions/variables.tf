
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

variable "FUNCTIONS_WORKER_RUNTIME" {
  type = string
}