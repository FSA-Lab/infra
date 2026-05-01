variable "aks_name" {
  type        = string
  description = "AKS cluster name."
  validation {
    condition     = length(trimspace(var.aks_name)) > 0
    error_message = "aks_name must not be empty."
  }
}

variable "aks_location" {
  type        = string
  description = "AKS region. Must be southeastasia."
  validation {
    condition     = lower(var.aks_location) == "southeastasia"
    error_message = "aks_location must be southeastasia."
  }
}

variable "aks_resource_group_name" {
  type        = string
  description = "Resource group name for AKS."
  validation {
    condition     = length(trimspace(var.aks_resource_group_name)) > 0
    error_message = "aks_resource_group_name must not be empty."
  }
}

variable "aks_dns_prefix" {
  type        = string
  description = "DNS prefix for AKS."
  validation {
    condition     = length(trimspace(var.aks_dns_prefix)) > 0
    error_message = "aks_dns_prefix must not be empty."
  }
}

variable "aks_vnet_name" {
  type        = string
  description = "VNet name."
  validation {
    condition     = length(trimspace(var.aks_vnet_name)) > 0
    error_message = "aks_vnet_name must not be empty."
  }
}

variable "aks_vnet_address_space" {
  type        = list(string)
  description = "VNet address space."
  validation {
    condition     = length(var.aks_vnet_address_space) > 0 && alltrue([for cidr in var.aks_vnet_address_space : can(cidrnetmask(cidr))])
    error_message = "aks_vnet_address_space must be a list of valid CIDRs."
  }
}

variable "aks_subnet_name" {
  type        = string
  description = "Subnet name."
  validation {
    condition     = length(trimspace(var.aks_subnet_name)) > 0
    error_message = "aks_subnet_name must not be empty."
  }
}

variable "aks_subnet_address_prefixes" {
  type        = list(string)
  description = "Subnet address prefixes."
  validation {
    condition     = length(var.aks_subnet_address_prefixes) > 0 && alltrue([for cidr in var.aks_subnet_address_prefixes : can(cidrnetmask(cidr))])
    error_message = "aks_subnet_address_prefixes must be a list of valid CIDRs."
  }
}

variable "aks_log_analytics_workspace_name" {
  type        = string
  description = "Log Analytics workspace name."
  validation {
    condition     = length(trimspace(var.aks_log_analytics_workspace_name)) > 0
    error_message = "aks_log_analytics_workspace_name must not be empty."
  }
}

variable "aks_log_analytics_sku" {
  type        = string
  description = "Log Analytics SKU (for example, PerGB2018)."
  validation {
    condition     = length(trimspace(var.aks_log_analytics_sku)) > 0
    error_message = "aks_log_analytics_sku must not be empty."
  }
}

variable "aks_log_analytics_retention_days" {
  type        = number
  description = "Log Analytics retention in days."
  validation {
    condition     = var.aks_log_analytics_retention_days >= 30
    error_message = "aks_log_analytics_retention_days must be at least 30."
  }
}

variable "aks_kubernetes_version" {
  type        = string
  description = "AKS Kubernetes version."
  validation {
    condition     = length(trimspace(var.aks_kubernetes_version)) > 0
    error_message = "aks_kubernetes_version must not be empty."
  }
}

variable "aks_network_plugin" {
  type        = string
  description = "AKS network plugin (azure or kubenet)."
  validation {
    condition     = contains(["azure", "kubenet"], var.aks_network_plugin)
    error_message = "aks_network_plugin must be azure or kubenet."
  }
}

variable "aks_network_policy" {
  type        = string
  description = "AKS network policy (azure or calico)."
  validation {
    condition     = contains(["azure", "calico"], var.aks_network_policy)
    error_message = "aks_network_policy must be azure or calico."
  }
}

variable "aks_service_cidr" {
  type        = string
  description = "AKS service CIDR."
  validation {
    condition     = can(cidrnetmask(var.aks_service_cidr))
    error_message = "aks_service_cidr must be a valid CIDR."
  }
}

variable "aks_dns_service_ip" {
  type        = string
  description = "AKS DNS service IP."
  validation {
    condition     = length(trimspace(var.aks_dns_service_ip)) > 0
    error_message = "aks_dns_service_ip must not be empty."
  }
}

variable "aks_system_node_count" {
  type        = number
  description = "System pool node count."
  validation {
    condition     = var.aks_system_node_count >= 1
    error_message = "aks_system_node_count must be at least 1."
  }
}

variable "aks_system_vm_size" {
  type        = string
  description = "System pool VM size (prefer Standard_B*)."
  validation {
    condition     = length(trimspace(var.aks_system_vm_size)) > 0
    error_message = "aks_system_vm_size must not be empty."
  }
}

variable "aks_tools_node_count" {
  type        = number
  description = "Tools pool node count."
  validation {
    condition     = var.aks_tools_node_count >= 1
    error_message = "aks_tools_node_count must be at least 1."
  }
}

variable "aks_tools_vm_size" {
  type        = string
  description = "Tools pool VM size (prefer Standard_B*)."
  validation {
    condition     = length(trimspace(var.aks_tools_vm_size)) > 0
    error_message = "aks_tools_vm_size must not be empty."
  }
}

variable "aks_apps_node_count" {
  type        = number
  description = "Apps pool node count."
  validation {
    condition     = var.aks_apps_node_count >= 1
    error_message = "aks_apps_node_count must be at least 1."
  }
}

variable "aks_apps_vm_size" {
  type        = string
  description = "Apps pool VM size (prefer Standard_B*)."
  validation {
    condition     = length(trimspace(var.aks_apps_vm_size)) > 0
    error_message = "aks_apps_vm_size must not be empty."
  }
}

variable "aks_tags" {
  type        = map(string)
  description = "Tags applied to AKS resources."
}