output "parser_service_storage_account" {
  value = var.enable_parser_service ? azurerm_storage_account.parser_service[0].name : null
}

output "parser_service_identity_client_id" {
  value = var.enable_parser_service ? azurerm_user_assigned_identity.parser_service[0].client_id : null
}

output "supabase_storage_account" {
  value = var.enable_supabase && var.supabase_use_s3_storage ? azurerm_storage_account.supabase_storage[0].name : null
}

output "supabase_storage_identity_client_id" {
  value = var.enable_supabase && var.supabase_use_s3_storage ? azurerm_user_assigned_identity.supabase_storage[0].client_id : null
}
