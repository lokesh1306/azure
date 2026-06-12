module "addons" {
  source = "../../../modules/addons"

  environment             = var.environment
  resource_group_name     = data.azurerm_resource_group.common.name
  location                = data.azurerm_resource_group.common.location
  cluster_name            = module.infrastructure.cluster_name
  cluster_oidc_issuer_url = module.infrastructure.cluster_oidc_issuer_url
  key_vault_id            = data.azurerm_key_vault.hub.id
  dns_zone_id             = var.dns_zone_id
}
