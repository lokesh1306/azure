output "resource_group_name" {
  value = data.azurerm_resource_group.spoke.name
}

output "resource_group_id" {
  value = data.azurerm_resource_group.spoke.id
}

output "location" {
  value = data.azurerm_resource_group.spoke.location
}

output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "acr_credentials_secret_name" {
  value = azurerm_key_vault_secret.acr_credentials.name
}
