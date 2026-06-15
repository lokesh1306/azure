module "platform" {
  source = "../platform"

  environment         = var.environment
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  subscription_id     = var.subscription_id

  cloud_environment    = var.cloud_environment
  private_dns_suffixes = var.private_dns_suffixes

  vnet_cidr                           = var.vnet_cidr
  availability_zones                  = var.availability_zones
  pod_cidr                            = var.pod_cidr
  service_cidr                        = var.service_cidr
  dns_service_ip                      = var.dns_service_ip
  existing_vnet_id                    = var.existing_vnet_id
  existing_aks_subnet_id              = var.existing_aks_subnet_id
  existing_private_endpoint_subnet_id = var.existing_private_endpoint_subnet_id

  kubernetes_version     = var.kubernetes_version
  admin_group_object_ids = var.admin_group_object_ids
}
