locals {
  env       = yamldecode(file(find_in_parent_folders("env.yaml")))
  constants = read_terragrunt_config(find_in_parent_folders("constants.hcl"))
  c         = local.constants.locals
  cloud     = local.c.cloud_environments[local.env.cloud_environment]
  domain    = lookup(local.env, "domain", "${local.env.name}.${local.c.base_domain}")
}

dependency "platform" {
  config_path                            = "../07-infrastructure"
  mock_outputs_merge_strategy_with_state = "shallow"
  mock_outputs = {
    cluster_name            = "mock-aks"
    cluster_id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.ContainerService/managedClusters/mock-aks"
    cluster_oidc_issuer_url = "https://mock.oic.azurecontainer.io/00000000-0000-0000-0000-000000000000/"
    cluster_private_fqdn    = "mock.privatelink.eastus.azmk8s.io"
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate", "destroy"]
}

dependency "secrets" {
  config_path                            = "../06-secrets"
  mock_outputs_merge_strategy_with_state = "shallow"
  mock_outputs = {
    key_vault_id                   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.KeyVault/vaults/mock-kv"
    acr_credentials_secret_name    = null
    acr_credentials_secret_version = null
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate", "destroy"]
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
        key                  = "${local.env.name}/08-apps/terraform.tfstate"
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
      environment         = "${local.cloud.provider_environment}"
      tenant_id           = "${local.env.tenant_id}"
      subscription_id     = "${local.env.subscription_id}"
      storage_use_azuread = true
      features {}
    }
  EOF
}

terraform {
  source = "${get_repo_root()}/azure_modules//spoke-apps"
}

inputs = {
  environment             = local.env.name
  resource_group_name     = local.env.resource_group_name
  subscription_id         = local.env.subscription_id
  cluster_name            = dependency.platform.outputs.cluster_name
  cluster_oidc_issuer_url = dependency.platform.outputs.cluster_oidc_issuer_url
  key_vault_id            = dependency.secrets.outputs.key_vault_id
  dns_zone_id             = local.env.dns_zone_id
  spoke_bootstrap         = local.env.spoke_bootstrap

  enable_optimized_nodepool = lookup(local.env, "enable_optimized_nodepool", true)
  optimized_nodepool_spec   = lookup(local.env, "optimized_nodepool_spec", null)

  admin_email                    = "admin@${local.domain}"
  org_name                       = local.env.name
  apps                           = lookup(local.env, "apps", {})
  supabase_config                = lookup(local.env, "supabase", {})
  acr_credentials_secret_name    = dependency.secrets.outputs.acr_credentials_secret_name
  acr_credentials_secret_version = dependency.secrets.outputs.acr_credentials_secret_version
}
