data "azurerm_client_config" "current" {}

data "azurerm_key_vault" "hub" {
  name                = element(split("/", trimsuffix(var.argocd_secrets_kv_uri, ".vault.azure.net/")), length(split("/", trimsuffix(var.argocd_secrets_kv_uri, ".vault.azure.net/"))) - 1)
  resource_group_name = data.azurerm_resource_group.common.name
}
