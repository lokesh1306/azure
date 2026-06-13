locals {
  unstructured_identifier = "${var.environment}-unstructured"
}

resource "random_password" "unstructured_api_key" {
  count = var.enable_unstructured ? 1 : 0

  length           = 32
  special          = true
  override_special = "-_"

  keepers = {
    seed = "${local.unstructured_identifier}-api-key-v1"
  }
}

resource "azurerm_key_vault_secret" "unstructured_secrets" {
  count = var.enable_unstructured ? 1 : 0

  name         = "${local.unstructured_identifier}-secrets"
  key_vault_id = var.key_vault_id
  value = jsonencode({
    unstructured_api_key = random_password.unstructured_api_key[0].result
  })

  lifecycle {
    ignore_changes = [value]
  }
}
