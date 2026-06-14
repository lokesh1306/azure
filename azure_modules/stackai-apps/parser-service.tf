locals {
  parser_identifier = "${var.environment}-parser"
}

resource "azurerm_storage_account" "parser_service" {
  count = var.enable_parser_service ? 1 : 0

  name                            = substr("${local.storage_name_base}parser", 0, 24)
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
}

resource "azurerm_storage_container" "parser_service" {
  count = var.enable_parser_service ? 1 : 0

  name                  = "parser"
  storage_account_id    = azurerm_storage_account.parser_service[0].id
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "parser_service" {
  count = var.enable_parser_service ? 1 : 0

  storage_account_id = azurerm_storage_account.parser_service[0].id

  rule {
    name    = "expire-parser-objects"
    enabled = true
    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["parser/"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.parser_service_retention_days
      }
    }
  }
}

resource "azurerm_user_assigned_identity" "parser_service" {
  count = var.enable_parser_service ? 1 : 0

  name                = "${var.environment}-parser-service"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_federated_identity_credential" "parser_service" {
  count = var.enable_parser_service ? 1 : 0

  name                      = "${var.environment}-parser-service"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.cluster_oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.parser_service[0].id
  subject                   = "system:serviceaccount:parser-service:parser-service"
}

resource "azurerm_role_assignment" "parser_service_storage" {
  count = var.enable_parser_service ? 1 : 0

  scope                = azurerm_storage_account.parser_service[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.parser_service[0].principal_id
}

resource "random_password" "parser_admin_token" {
  count = var.enable_parser_service ? 1 : 0

  length  = 64
  special = false

  keepers = {
    seed = "${local.parser_identifier}-admin-token-v1"
  }
}

resource "random_password" "parser_hmac_secret" {
  count = var.enable_parser_service ? 1 : 0

  length  = 128
  special = false

  keepers = {
    seed = "${local.parser_identifier}-hmac-secret-v1"
  }
}

resource "azurerm_key_vault_secret" "parser_secrets" {
  count = var.enable_parser_service ? 1 : 0

  name         = "${local.parser_identifier}-secrets"
  key_vault_id = var.key_vault_id
  value = jsonencode({
    admin_token          = random_password.parser_admin_token[0].result
    api_key_hmac_secret  = random_password.parser_hmac_secret[0].result
    storage_account_name = azurerm_storage_account.parser_service[0].name
    container_name       = azurerm_storage_container.parser_service[0].name
    s3_bucket_name       = azurerm_storage_account.parser_service[0].name
  })

  lifecycle {
    ignore_changes = [value]
  }
}
