locals {
  weaviate_identifier = "${var.environment}-weaviate"
}

resource "random_password" "weaviate_api_key" {
  count = var.enable_weaviate ? 1 : 0

  length  = 32
  special = false

  keepers = {
    seed = "${local.weaviate_identifier}-api-key-v1"
  }
}

resource "azurerm_key_vault_secret" "weaviate_secrets" {
  count = var.enable_weaviate ? 1 : 0

  name         = "${local.weaviate_identifier}-secrets"
  key_vault_id = var.key_vault_id
  value = jsonencode({
    weaviate_key = random_password.weaviate_api_key[0].result
  })

  lifecycle {
    ignore_changes = [value]
  }
}
