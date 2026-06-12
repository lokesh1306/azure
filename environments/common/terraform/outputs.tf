output "resource_group_name" {
  value = data.azurerm_resource_group.common.name
}

output "vnet_id" {
  value = module.infrastructure.vnet_id
}

output "cluster_name" {
  value = module.infrastructure.cluster_name
}

output "cluster_private_fqdn" {
  value = module.infrastructure.cluster_private_fqdn
}

output "cluster_oidc_issuer_url" {
  description = "Use this URL as the issuer in each spoke App Registration's federated identity credential."
  value       = module.infrastructure.cluster_oidc_issuer_url
}

output "configure_kubectl" {
  description = "Command to configure kubectl against the hub cluster."
  value       = "az aks get-credentials --resource-group ${data.azurerm_resource_group.common.name} --name ${module.infrastructure.cluster_name} --overwrite-existing && kubelogin convert-kubeconfig -l azurecli"
}

output "nat_public_ip" {
  value = module.infrastructure.nat_public_ip
}
