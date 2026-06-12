locals {
  env = yamldecode(file(find_in_parent_folders("env.yaml")))
}

remote_state {
  backend = "azurerm"
  config = {
    resource_group_name  = local.env.resource_group_name
    storage_account_name = "${local.env.name}stackaitfstate"
    container_name       = "tfstate"
    key                  = "${local.env.name}/${basename(path_relative_to_include())}/terraform.tfstate"
    use_azuread_auth     = true
    subscription_id      = local.env.subscription_id
    tenant_id            = local.env.tenant_id
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

errors {
  retry "transient_azure_errors" {
    retryable_errors = [
      "(?s).*AuthorizationFailed.*",
      "(?s).*Forbidden.*",
      "(?s).*RequestThrottled.*",
      "(?s).*TooManyRequests.*",
      "(?s).*ServiceUnavailable.*",
      "(?s).*OperationNotAllowed.*",
    ]
    max_attempts       = 3
    sleep_interval_sec = 30
  }
}
