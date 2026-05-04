variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "storage_account_name" {
  type = string
  description = "Must be globally unique, 3-24 lowercase alphanumeric"
}

variable "container_name" {
  type = string
}

variable "account_replication_type" {
  type = string
  description = "LRS, GRS, ZRS, etc."
}

variable "tags" {
  type = map(string)
}