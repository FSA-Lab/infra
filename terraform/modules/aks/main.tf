resource "azurerm_resource_group" "aks_rg" {
  name     = var.AKS_RESOURCE_GROUP_NAME
  location = var.AKS_LOCATION
  tags     = var.AKS_TAGS
}

resource "azurerm_virtual_network" "aks_vnet" {
  name                = var.AKS_VNET_NAME
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  address_space       = var.AKS_VNET_ADDRESS_SPACE
  tags                = var.AKS_TAGS
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = var.AKS_SUBNET_NAME
  resource_group_name  = azurerm_resource_group.aks_rg.name
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  address_prefixes     = var.AKS_SUBNET_ADDRESS_PREFIXES
}

resource "azurerm_log_analytics_workspace" "aks_log" {
  name                = var.AKS_LOG_ANALYTICS_WORKSPACE_NAME
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  sku                 = var.AKS_LOG_ANALYTICS_SKU
  retention_in_days   = var.AKS_LOG_ANALYTICS_RETENTION_DAYS
  tags                = var.AKS_TAGS
}

resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = var.AKS_NAME
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = var.AKS_DNS_PREFIX
  kubernetes_version  = var.AKS_KUBERNETES_VERSION

  default_node_pool {
    name           = "system"
    vm_size        = var.AKS_SYSTEM_VM_SIZE
    node_count     = var.AKS_SYSTEM_NODE_COUNT
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
    node_labels = {
      "workload" = "system"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = var.AKS_NETWORK_PLUGIN
    network_policy = var.AKS_NETWORK_POLICY
    service_cidr   = var.AKS_SERVICE_CIDR
    dns_service_ip = var.AKS_DNS_SERVICE_IP
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks_log.id
  }

  role_based_access_control_enabled = true
  tags                              = var.AKS_TAGS

  lifecycle {
    ignore_changes = [
      default_node_pool[0].upgrade_settings
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "aks_tools" {
  name                  = "tools"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_cluster.id
  vm_size               = var.AKS_TOOLS_VM_SIZE
  node_count            = var.AKS_TOOLS_NODE_COUNT
  vnet_subnet_id        = azurerm_subnet.aks_subnet.id
  mode                  = "User"
  node_labels = {
    "workload" = "tools"
  }
  node_taints = [
    "workload=tools:NoSchedule"
  ]

  lifecycle {
    ignore_changes = [
      tags,
      upgrade_settings
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "aks_apps" {
  name                  = "apps"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_cluster.id
  vm_size               = var.AKS_APPS_VM_SIZE
  node_count            = var.AKS_APPS_NODE_COUNT
  vnet_subnet_id        = azurerm_subnet.aks_subnet.id
  mode                  = "User"
  node_labels = {
    "workload" = "apps"
  }
  node_taints = [
    "workload=apps:NoSchedule"
  ]
  lifecycle {
    ignore_changes = [
      tags,
      upgrade_settings
    ]
  }
}