locals {
  storage_name_base = replace(lower(var.environment), "-", "")

  app_secrets = {
    parser       = { create = var.enable_parser_service, name = "parser-secrets" }
    mongodb      = { create = var.enable_mongodb, name = "mongodb-secrets" }
    weaviate     = { create = var.enable_weaviate, name = "weaviate-secrets" }
    unstructured = { create = var.enable_unstructured, name = "unstructured-secrets" }
    supabase     = { create = var.enable_supabase, name = "supabase-secrets" }
  }

  enabled_app_secrets = { for k, v in local.app_secrets : k => v if v.create }
}

resource "random_password" "app" {
  for_each = local.enabled_app_secrets

  length  = 32
  special = false
}

resource "azurerm_key_vault_secret" "app" {
  for_each = local.enabled_app_secrets

  name         = each.value.name
  key_vault_id = var.key_vault_id
  value = jsonencode({
    password = random_password.app[each.key].result
  })

  lifecycle {
    ignore_changes = [value]
  }
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

resource "azurerm_storage_account" "supabase_storage" {
  count = var.enable_supabase && var.supabase_use_s3_storage ? 1 : 0

  name                            = substr("${local.storage_name_base}supabase", 0, 24)
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "supabase_storage" {
  count = var.enable_supabase && var.supabase_use_s3_storage ? 1 : 0

  name                  = "supabase"
  storage_account_id    = azurerm_storage_account.supabase_storage[0].id
  container_access_type = "private"
}

resource "azurerm_user_assigned_identity" "supabase_storage" {
  count = var.enable_supabase && var.supabase_use_s3_storage ? 1 : 0

  name                = "${var.environment}-supabase-storage"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_federated_identity_credential" "supabase_storage" {
  count = var.enable_supabase && var.supabase_use_s3_storage ? 1 : 0

  name                      = "${var.environment}-supabase-storage"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.cluster_oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.supabase_storage[0].id
  subject                   = "system:serviceaccount:supabase:supabase-storage"
}

resource "azurerm_role_assignment" "supabase_storage" {
  count = var.enable_supabase && var.supabase_use_s3_storage ? 1 : 0

  scope                = azurerm_storage_account.supabase_storage[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.supabase_storage[0].principal_id
}
