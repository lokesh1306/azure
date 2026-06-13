locals {
  mongodb_identifier = "${var.environment}-mongodb"
}

resource "random_password" "mongodb_admin" {
  count = var.enable_mongodb ? 1 : 0

  length  = 32
  special = false

  keepers = {
    seed = "${local.mongodb_identifier}-admin-password-v1"
  }
}

resource "random_password" "mongodb_metrics" {
  count = var.enable_mongodb ? 1 : 0

  length           = 32
  special          = true
  override_special = "!*()-_[]{}<>"

  keepers = {
    seed = "${local.mongodb_identifier}-metrics-password-v1"
  }
}

resource "azurerm_key_vault_secret" "mongodb_secrets" {
  count = var.enable_mongodb ? 1 : 0

  name         = "${local.mongodb_identifier}-secrets"
  key_vault_id = var.key_vault_id
  value = jsonencode({
    admin_username   = "admin"
    admin_password   = random_password.mongodb_admin[0].result
    metrics_username = "metrics"
    metrics_password = random_password.mongodb_metrics[0].result
  })

  lifecycle {
    ignore_changes = [value]
  }
}
