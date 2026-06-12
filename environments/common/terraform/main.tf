data "azurerm_resource_group" "common" {
  name = var.resource_group_name
}

module "infrastructure" {
  source = "../../../modules/infrastructure"

  environment         = var.environment
  resource_group_name = data.azurerm_resource_group.common.name
  tenant_id           = var.tenant_id
  subscription_id     = var.subscription_id

  cloud_environment = "commercial"
  private_dns_suffixes = {
    keyvault     = "privatelink.vaultcore.azure.net"
    storage_blob = "privatelink.blob.core.windows.net"
  }

  vnet_cidr              = var.vnet_cidr
  kubernetes_version     = var.kubernetes_version
  admin_group_object_ids = var.admin_group_object_ids
}
