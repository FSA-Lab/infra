output "aks_resource_group_name" {
  description = "The AKS resource group name."
  value       = azurerm_resource_group.aks_rg.name
}

output "aks_virtual_network_id" {
  description = "The AKS virtual network ID."
  value       = azurerm_virtual_network.aks_vnet.id
}

output "aks_subnet_id" {
  description = "The AKS subnet ID."
  value       = azurerm_subnet.aks_subnet.id
}

output "aks_log_analytics_workspace_id" {
  description = "The Log Analytics workspace ID used by AKS."
  value       = azurerm_log_analytics_workspace.aks_log.id
}

output "aks_cluster_name" {
  description = "The AKS cluster name."
  value       = azurerm_kubernetes_cluster.aks_cluster.name
}

output "aks_cluster_id" {
  description = "The AKS cluster resource ID."
  value       = azurerm_kubernetes_cluster.aks_cluster.id
}

output "aks_cluster_fqdn" {
  description = "The AKS cluster FQDN."
  value       = azurerm_kubernetes_cluster.aks_cluster.fqdn
}

output "aks_admin_kubeconfig_raw" {
  description = "The raw admin kubeconfig for the AKS cluster."
  value       = azurerm_kubernetes_cluster.aks_cluster.kube_admin_config_raw
  sensitive   = true
}

output "aks_user_kubeconfig_raw" {
  description = "The raw user kubeconfig for the AKS cluster."
  value       = azurerm_kubernetes_cluster.aks_cluster.kube_config_raw
  sensitive   = true
}

