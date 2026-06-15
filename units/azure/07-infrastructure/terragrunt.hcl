locals {
  env       = yamldecode(file(find_in_parent_folders("env.yaml")))
  constants = read_terragrunt_config(find_in_parent_folders("constants.hcl"))
  c         = local.constants.locals
  cloud     = local.c.cloud_environments[local.env.cloud_environment]
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      backend "azurerm" {
        resource_group_name  = "${local.env.resource_group_name}"
        storage_account_name = "${local.env.name}stackaitfstate"
        container_name       = "tfstate"
        key                  = "${local.env.name}/07-infrastructure/terraform.tfstate"
        use_azuread_auth     = true
        subscription_id      = "${local.env.subscription_id}"
        tenant_id            = "${local.env.tenant_id}"
      }
    }
  EOF
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "azurerm" {
      environment     = "${local.cloud.provider_environment}"
      tenant_id       = "${local.env.tenant_id}"
      subscription_id = "${local.env.subscription_id}"
      features {}
    }
  EOF
}

terraform {
  source = "${get_repo_root()}/azure_modules//infrastructure"
}

inputs = {
  environment         = local.env.name
  resource_group_name = local.env.resource_group_name
  tenant_id           = local.env.tenant_id
  subscription_id     = local.env.subscription_id

  cloud_environment = local.env.cloud_environment
  private_dns_suffixes = {
    keyvault     = local.cloud.keyvault_dns
    storage_blob = local.cloud.storage_blob_dns
  }

  vnet_cidr                           = lookup(local.env, "vnet_cidr", "10.50.0.0/16")
  availability_zones                  = lookup(local.env, "availability_zones", ["1", "2", "3"])
  system_vm_size                      = lookup(local.env, "system_vm_size", "Standard_D2s_v5")
  pod_cidr                            = lookup(local.env, "pod_cidr", "10.244.0.0/16")
  service_cidr                        = lookup(local.env, "service_cidr", "172.16.0.0/16")
  dns_service_ip                      = lookup(local.env, "dns_service_ip", "172.16.0.10")
  existing_vnet_id                    = lookup(local.env, "existing_vnet_id", null)
  existing_aks_subnet_id              = lookup(local.env, "existing_aks_subnet_id", null)
  existing_private_endpoint_subnet_id = lookup(local.env, "existing_private_endpoint_subnet_id", null)

  kubernetes_version     = lookup(local.env, "kubernetes_version", "1.35")
  admin_group_object_ids = lookup(local.env, "admin_group_object_ids", [])
}
