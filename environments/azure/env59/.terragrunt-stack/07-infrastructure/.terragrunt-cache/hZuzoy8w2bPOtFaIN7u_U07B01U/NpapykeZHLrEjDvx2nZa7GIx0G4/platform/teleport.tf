locals {
  create_teleport_agent = var.enable_teleport_agent
}

resource "azurerm_user_assigned_identity" "teleport_agent" {
  count = local.create_teleport_agent ? 1 : 0

  name                = "${var.environment}-teleport-agent"
  resource_group_name = data.azurerm_resource_group.spoke.name
  location            = data.azurerm_resource_group.spoke.location
}

resource "azurerm_federated_identity_credential" "teleport_agent" {
  count = local.create_teleport_agent ? 1 : 0

  name                      = "${var.environment}-teleport-agent"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.this.oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.teleport_agent[0].id
  subject                   = "system:serviceaccount:${var.teleport_agent_namespace}:${var.teleport_agent_service_account}"
}
