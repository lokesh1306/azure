output "external_secrets_client_id" {
  value = azurerm_user_assigned_identity.addon["external_secrets"].client_id
}

output "external_dns_client_id" {
  value = azurerm_user_assigned_identity.addon["external_dns"].client_id
}

output "cert_manager_client_id" {
  value = azurerm_user_assigned_identity.addon["cert_manager"].client_id
}
