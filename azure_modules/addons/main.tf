locals {
  addons = {
    external_secrets = {
      namespace       = "external-secrets"
      service_account = "external-secrets"
    }
    external_dns = {
      namespace       = "external-dns"
      service_account = "external-dns"
    }
    cert_manager = {
      namespace       = "cert-manager"
      service_account = "cert-manager"
    }
  }

  has_kv  = var.key_vault_id != null && var.key_vault_id != ""
  has_dns = var.dns_zone_id != null && var.dns_zone_id != ""
}

resource "azurerm_user_assigned_identity" "addon" {
  for_each = local.addons

  name                = "${var.environment}-${replace(each.key, "_", "-")}"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_federated_identity_credential" "addon" {
  for_each = local.addons

  name                      = "${var.environment}-${replace(each.key, "_", "-")}"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.cluster_oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.addon[each.key].id
  subject                   = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
}

resource "azurerm_role_assignment" "external_secrets_kv" {
  count                = local.has_kv ? 1 : 0
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.addon["external_secrets"].principal_id
}

resource "azurerm_role_assignment" "external_dns_zone" {
  count                = local.has_dns ? 1 : 0
  scope                = var.dns_zone_id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.addon["external_dns"].principal_id
}

resource "azurerm_role_assignment" "cert_manager_zone" {
  count                = local.has_dns ? 1 : 0
  scope                = var.dns_zone_id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.addon["cert_manager"].principal_id
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azurerm_role_assignment" "external_secrets_rg_reader" {
  scope                = data.azurerm_resource_group.this.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.addon["external_secrets"].principal_id
}
