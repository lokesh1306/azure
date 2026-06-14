locals {
  env       = yamldecode(file(find_in_parent_folders("env.yaml")))
  constants = read_terragrunt_config(find_in_parent_folders("constants.hcl"))
  c         = local.constants.locals
  cloud     = local.c.cloud_environments[local.env.cloud_environment]
  secrets   = yamldecode(run_cmd("--terragrunt-quiet", "sops", "-d", "${dirname(find_in_parent_folders("env.yaml"))}/secrets.yaml"))
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
        key                  = "${local.env.name}/06-secrets/terraform.tfstate"
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

    provider "azuread" {
      environment = "${local.cloud.provider_environment}"
      tenant_id   = "${local.env.tenant_id}"
    }
  EOF
}

terraform {
  source = "${get_repo_root()}/azure_modules//bootstrap-secrets"
}

inputs = {
  environment         = local.env.name
  resource_group_name = local.env.resource_group_name
  tenant_id           = local.env.tenant_id

  customer_secrets = local.secrets.customer
  apps_temporal    = lookup(lookup(local.env, "apps", {}), "temporal", true)
  acr_credentials = {
    server   = local.env.acr.server
    username = local.secrets.infra.acr.username
    password = local.secrets.infra.acr.password
  }
}
