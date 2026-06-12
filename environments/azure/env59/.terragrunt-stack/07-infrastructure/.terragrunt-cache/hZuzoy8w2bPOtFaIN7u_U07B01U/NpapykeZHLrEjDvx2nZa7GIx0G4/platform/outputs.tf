output "vnet_id" {
  value = local.vnet_id
}

output "aks_subnet_id" {
  value = local.aks_subnet_id
}

output "private_endpoint_subnet_id" {
  value = local.private_endpoint_subnet_id
}

output "nat_public_ip" {
  value = local.create_vnet ? azurerm_public_ip.nat[0].ip_address : null
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.this.id
}

output "cluster_oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "cluster_private_fqdn" {
  value = azurerm_kubernetes_cluster.this.private_fqdn
}

output "cluster_host" {
  value = azurerm_kubernetes_cluster.this.kube_config[0].host
}

output "cluster_certificate_authority_data" {
  value     = azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
  sensitive = true
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "kubelet_identity_client_id" {
  value = azurerm_kubernetes_cluster.this.kubelet_identity[0].client_id
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.this.id
}

output "teleport_agent_identity_client_id" {
  value = local.create_teleport_agent ? azurerm_user_assigned_identity.teleport_agent[0].client_id : null
}

output "teleport_agent_identity_principal_id" {
  value = local.create_teleport_agent ? azurerm_user_assigned_identity.teleport_agent[0].principal_id : null
}
