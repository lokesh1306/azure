data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "spoke" {
  name = var.resource_group_name
}

data "azurerm_subnet" "existing_aks" {
  count                = var.existing_vnet_id == null ? 0 : 1
  name                 = element(split("/", var.existing_aks_subnet_id), length(split("/", var.existing_aks_subnet_id)) - 1)
  virtual_network_name = element(split("/", var.existing_vnet_id), length(split("/", var.existing_vnet_id)) - 1)
  resource_group_name  = element(split("/", var.existing_vnet_id), length(split("/", var.existing_vnet_id)) - 5)
}
