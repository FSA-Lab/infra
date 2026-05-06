variable "AKS_NAME" {
  type        = string
  description = "AKS cluster name."
  validation {
    condition     = length(trimspace(var.AKS_NAME)) > 0
    error_message = "AKS_NAME must not be empty."
  }
}

variable "AKS_LOCATION" {
  type        = string
  description = "AKS region. Must be southeastasia."
  validation {
    condition     = lower(var.AKS_LOCATION) == "southeastasia"
    error_message = "AKS_LOCATION must be southeastasia."
  }
}

variable "AKS_RESOURCE_GROUP_NAME" {
  type        = string
  description = "Resource group name for AKS."
  validation {
    condition     = length(trimspace(var.AKS_RESOURCE_GROUP_NAME)) > 0
    error_message = "AKS_RESOURCE_GROUP_NAME must not be empty."
  }
}

variable "AKS_DNS_PREFIX" {
  type        = string
  description = "DNS prefix for AKS."
  validation {
    condition     = length(trimspace(var.AKS_DNS_PREFIX)) > 0
    error_message = "AKS_DNS_PREFIX must not be empty."
  }
}

variable "AKS_VNET_NAME" {
  type        = string
  description = "VNet name."
  validation {
    condition     = length(trimspace(var.AKS_VNET_NAME)) > 0
    error_message = "AKS_VNET_NAME must not be empty."
  }
}

variable "AKS_VNET_ADDRESS_SPACE" {
  type        = list(string)
  description = "VNet address space."
  validation {
    condition     = length(var.AKS_VNET_ADDRESS_SPACE) > 0 && alltrue([for cidr in var.AKS_VNET_ADDRESS_SPACE : can(cidrnetmask(cidr))])
    error_message = "AKS_VNET_ADDRESS_SPACE must be a list of valid CIDRs."
  }
}

variable "AKS_SUBNET_NAME" {
  type        = string
  description = "Subnet name."
  validation {
    condition     = length(trimspace(var.AKS_SUBNET_NAME)) > 0
    error_message = "AKS_SUBNET_NAME must not be empty."
  }
}

variable "AKS_SUBNET_ADDRESS_PREFIXES" {
  type        = list(string)
  description = "Subnet address prefixes."
  validation {
    condition     = length(var.AKS_SUBNET_ADDRESS_PREFIXES) > 0 && alltrue([for cidr in var.AKS_SUBNET_ADDRESS_PREFIXES : can(cidrnetmask(cidr))])
    error_message = "AKS_SUBNET_ADDRESS_PREFIXES must be a list of valid CIDRs."
  }
}

variable "AKS_LOG_ANALYTICS_WORKSPACE_NAME" {
  type        = string
  description = "Log Analytics workspace name."
  validation {
    condition     = length(trimspace(var.AKS_LOG_ANALYTICS_WORKSPACE_NAME)) > 0
    error_message = "AKS_LOG_ANALYTICS_WORKSPACE_NAME must not be empty."
  }
}

variable "AKS_LOG_ANALYTICS_SKU" {
  type        = string
  description = "Log Analytics SKU (for example, PerGB2018)."
  validation {
    condition     = length(trimspace(var.AKS_LOG_ANALYTICS_SKU)) > 0
    error_message = "AKS_LOG_ANALYTICS_SKU must not be empty."
  }
}

variable "AKS_LOG_ANALYTICS_RETENTION_DAYS" {
  type        = number
  description = "Log Analytics retention in days."
  validation {
    condition     = var.AKS_LOG_ANALYTICS_RETENTION_DAYS >= 30
    error_message = "AKS_LOG_ANALYTICS_RETENTION_DAYS must be at least 30."
  }
}

variable "AKS_KUBERNETES_VERSION" {
  type        = string
  description = "AKS Kubernetes version."
  validation {
    condition     = length(trimspace(var.AKS_KUBERNETES_VERSION)) > 0
    error_message = "AKS_KUBERNETES_VERSION must not be empty."
  }
}

variable "AKS_NETWORK_PLUGIN" {
  type        = string
  description = "AKS network plugin (azure or kubenet)."
  validation {
    condition     = contains(["azure", "kubenet"], var.AKS_NETWORK_PLUGIN)
    error_message = "AKS_NETWORK_PLUGIN must be azure or kubenet."
  }
}

variable "AKS_NETWORK_POLICY" {
  type        = string
  description = "AKS network policy (azure or calico)."
  validation {
    condition     = contains(["azure", "calico"], var.AKS_NETWORK_POLICY)
    error_message = "AKS_NETWORK_POLICY must be azure or calico."
  }
}

variable "AKS_SERVICE_CIDR" {
  type        = string
  description = "AKS service CIDR."
  validation {
    condition     = can(cidrnetmask(var.AKS_SERVICE_CIDR))
    error_message = "AKS_SERVICE_CIDR must be a valid CIDR."
  }
}

variable "AKS_DNS_SERVICE_IP" {
  type        = string
  description = "AKS DNS service IP."
  validation {
    condition     = length(trimspace(var.AKS_DNS_SERVICE_IP)) > 0
    error_message = "AKS_DNS_SERVICE_IP must not be empty."
  }
}

variable "AKS_SYSTEM_NODE_COUNT" {
  type        = number
  description = "System pool node count."
  validation {
    condition     = var.AKS_SYSTEM_NODE_COUNT >= 1
    error_message = "AKS_SYSTEM_NODE_COUNT must be at least 1."
  }
}

variable "AKS_SYSTEM_VM_SIZE" {
  type        = string
  description = "System pool VM size (prefer Standard_B*)."
  validation {
    condition     = length(trimspace(var.AKS_SYSTEM_VM_SIZE)) > 0
    error_message = "AKS_SYSTEM_VM_SIZE must not be empty."
  }
}

variable "AKS_TOOLS_NODE_COUNT" {
  type        = number
  description = "Tools pool node count."
  validation {
    condition     = var.AKS_TOOLS_NODE_COUNT >= 1
    error_message = "AKS_TOOLS_NODE_COUNT must be at least 1."
  }
}

variable "AKS_TOOLS_VM_SIZE" {
  type        = string
  description = "Tools pool VM size (prefer Standard_B*)."
  validation {
    condition     = length(trimspace(var.AKS_TOOLS_VM_SIZE)) > 0
    error_message = "AKS_TOOLS_VM_SIZE must not be empty."
  }
}

variable "AKS_APPS_NODE_COUNT" {
  type        = number
  description = "Apps pool node count."
  validation {
    condition     = var.AKS_APPS_NODE_COUNT >= 1
    error_message = "AKS_APPS_NODE_COUNT must be at least 1."
  }
}

variable "AKS_APPS_VM_SIZE" {
  type        = string
  description = "Apps pool VM size (prefer Standard_B*)."
  validation {
    condition     = length(trimspace(var.AKS_APPS_VM_SIZE)) > 0
    error_message = "AKS_APPS_VM_SIZE must not be empty."
  }
}

variable "AKS_TAGS" {
  type        = map(string)
  description = "Tags applied to AKS resources."
}