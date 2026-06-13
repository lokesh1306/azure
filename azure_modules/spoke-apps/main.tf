data "azurerm_resource_group" "spoke" {
  name = var.resource_group_name
}

module "addons" {
  source = "../addons"

  environment             = var.environment
  resource_group_name     = var.resource_group_name
  location                = data.azurerm_resource_group.spoke.location
  cluster_name            = var.cluster_name
  cluster_oidc_issuer_url = var.cluster_oidc_issuer_url
  key_vault_id            = var.key_vault_id
  dns_zone_id             = var.dns_zone_id

  enable_optimized_nodepool = var.enable_optimized_nodepool
  optimized_nodepool_spec   = var.optimized_nodepool_spec
}

module "apps" {
  source = "../stackai-apps"

  environment             = var.environment
  resource_group_name     = var.resource_group_name
  location                = data.azurerm_resource_group.spoke.location
  cluster_oidc_issuer_url = var.cluster_oidc_issuer_url
  key_vault_id            = var.key_vault_id
  admin_email             = var.admin_email
  org_name                = var.org_name

  enable_parser_service = var.apps.parser_service
  enable_mongodb        = var.apps.mongodb
  enable_weaviate       = var.apps.weaviate
  enable_unstructured   = var.apps.unstructured

  enable_supabase          = var.apps.supabase
  supabase_use_external_db = var.supabase_config.use_external_db
  supabase_use_s3_storage  = var.supabase_config.use_s3_storage
  supabase_enable_saml     = var.supabase_config.enable_saml

  depends_on = [module.addons]
}

module "spoke_bootstrap" {
  source = "../spoke-bootstrap"

  environment                 = var.environment
  resource_group_name         = var.resource_group_name
  subscription_id             = var.subscription_id
  cluster_name                = var.cluster_name
  trust_domain                = var.spoke_bootstrap.trust_domain
  tenant_domain               = var.spoke_bootstrap.tenant_domain
  hub_spire_endpoint          = var.spoke_bootstrap.hub_spire_endpoint
  hub_principal_endpoint      = var.spoke_bootstrap.hub_principal_endpoint
  hub_trust_bundle            = var.spoke_bootstrap.hub_trust_bundle
  key_vault_id                = var.key_vault_id
  acr_credentials_secret_name = var.acr_credentials_secret_name

  depends_on = [module.addons]
}
