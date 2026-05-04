resource "azurerm_resource_group" "aks_rg" {
  name     = var.aks_resource_group_name
  location = var.aks_location
  tags     = var.aks_tags
}

resource "azurerm_virtual_network" "aks_vnet" {
  name                = var.aks_vnet_name
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  address_space       = var.aks_vnet_address_space
  tags                = var.aks_tags
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = var.aks_subnet_name
  resource_group_name  = azurerm_resource_group.aks_rg.name
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  address_prefixes     = var.aks_subnet_address_prefixes
}

resource "azurerm_log_analytics_workspace" "aks_log" {
  name                = var.aks_log_analytics_workspace_name
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  sku                 = var.aks_log_analytics_sku
  retention_in_days   = var.aks_log_analytics_retention_days
  tags                = var.aks_tags
}

resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = var.aks_name
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = var.aks_dns_prefix
  kubernetes_version  = var.aks_kubernetes_version

  default_node_pool {
    name           = "system"
    vm_size        = var.aks_system_vm_size
    node_count     = var.aks_system_node_count
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
    node_labels = {
      "workload" = "system"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = var.aks_network_plugin
    network_policy = var.aks_network_policy
    service_cidr   = var.aks_service_cidr
    dns_service_ip = var.aks_dns_service_ip
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks_log.id
  }

  role_based_access_control_enabled = true
  tags                              = var.aks_tags
}

resource "azurerm_kubernetes_cluster_node_pool" "aks_tools" {
  name                  = "tools"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_cluster.id
  vm_size               = var.aks_tools_vm_size
  node_count            = var.aks_tools_node_count
  vnet_subnet_id        = azurerm_subnet.aks_subnet.id
  mode                  = "User"
  node_labels = {
    "workload" = "tools"
  }
  node_taints = [
    "workload=tools:NoSchedule"
  ]
}

resource "azurerm_kubernetes_cluster_node_pool" "aks_apps" {
  name                  = "apps"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_cluster.id
  vm_size               = var.aks_apps_vm_size
  node_count            = var.aks_apps_node_count
  vnet_subnet_id        = azurerm_subnet.aks_subnet.id
  mode                  = "User"
  node_labels = {
    "workload" = "apps"
  }
  node_taints = [
    "workload=apps:NoSchedule"
  ]
}