output "vnet_id" {
  value = module.platform.vnet_id
}

output "aks_subnet_id" {
  value = module.platform.aks_subnet_id
}

output "private_endpoint_subnet_id" {
  value = module.platform.private_endpoint_subnet_id
}

output "cluster_name" {
  value = module.platform.cluster_name
}

output "cluster_id" {
  value = module.platform.cluster_id
}

output "cluster_oidc_issuer_url" {
  value = module.platform.cluster_oidc_issuer_url
}

output "cluster_private_fqdn" {
  value = module.platform.cluster_private_fqdn
}

output "cluster_host" {
  value     = module.platform.cluster_host
  sensitive = true
}

output "cluster_certificate_authority_data" {
  value     = module.platform.cluster_certificate_authority_data
  sensitive = true
}

output "kubelet_identity_object_id" {
  value = module.platform.kubelet_identity_object_id
}

output "log_analytics_workspace_id" {
  value = module.platform.log_analytics_workspace_id
}

output "nat_public_ip" {
  value = module.platform.nat_public_ip
}
