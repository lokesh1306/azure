locals {
  create_vnet = var.existing_vnet_id == null

  aks_subnet_cidr              = cidrsubnet(var.vnet_cidr, 4, 0)
  private_endpoint_subnet_cidr = cidrsubnet(var.vnet_cidr, 4, 1)

  aks_subnet_id              = local.create_vnet ? azurerm_subnet.aks[0].id : var.existing_aks_subnet_id
  private_endpoint_subnet_id = local.create_vnet ? azurerm_subnet.private_endpoints[0].id : var.existing_private_endpoint_subnet_id
  vnet_id                    = local.create_vnet ? azurerm_virtual_network.this[0].id : var.existing_vnet_id
}

resource "azurerm_virtual_network" "this" {
  count = local.create_vnet ? 1 : 0

  name                = "${var.environment}-vnet"
  resource_group_name = data.azurerm_resource_group.spoke.name
  location            = data.azurerm_resource_group.spoke.location
  address_space       = [var.vnet_cidr]
}

resource "azurerm_subnet" "aks" {
  count = local.create_vnet ? 1 : 0

  name                 = "${var.environment}-aks-subnet"
  resource_group_name  = data.azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.this[0].name
  address_prefixes     = [local.aks_subnet_cidr]
}

resource "azurerm_subnet" "private_endpoints" {
  count = local.create_vnet ? 1 : 0

  name                              = "${var.environment}-pe-subnet"
  resource_group_name               = data.azurerm_resource_group.spoke.name
  virtual_network_name              = azurerm_virtual_network.this[0].name
  address_prefixes                  = [local.private_endpoint_subnet_cidr]
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_network_security_group" "aks" {
  count = local.create_vnet ? 1 : 0

  name                = "${var.environment}-aks-nsg"
  resource_group_name = data.azurerm_resource_group.spoke.name
  location            = data.azurerm_resource_group.spoke.location
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  count = local.create_vnet ? 1 : 0

  subnet_id                 = azurerm_subnet.aks[0].id
  network_security_group_id = azurerm_network_security_group.aks[0].id
}

resource "azurerm_public_ip" "nat" {
  count = local.create_vnet ? 1 : 0

  name                = "${var.environment}-nat-pip"
  resource_group_name = data.azurerm_resource_group.spoke.name
  location            = data.azurerm_resource_group.spoke.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

resource "azurerm_nat_gateway" "this" {
  count = local.create_vnet ? 1 : 0

  name                = "${var.environment}-natgw"
  resource_group_name = data.azurerm_resource_group.spoke.name
  location            = data.azurerm_resource_group.spoke.location
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count = local.create_vnet ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "aks" {
  count = local.create_vnet ? 1 : 0

  subnet_id      = azurerm_subnet.aks[0].id
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}

resource "azurerm_private_dns_zone" "keyvault" {
  count = local.create_vnet ? 1 : 0

  name                = var.private_dns_suffixes.keyvault
  resource_group_name = data.azurerm_resource_group.spoke.name
}

resource "azurerm_private_dns_zone" "storage_blob" {
  count = local.create_vnet ? 1 : 0

  name                = var.private_dns_suffixes.storage_blob
  resource_group_name = data.azurerm_resource_group.spoke.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  count = local.create_vnet ? 1 : 0

  name                  = "${var.environment}-kv-link"
  resource_group_name   = data.azurerm_resource_group.spoke.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault[0].name
  virtual_network_id    = azurerm_virtual_network.this[0].id
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_blob" {
  count = local.create_vnet ? 1 : 0

  name                  = "${var.environment}-blob-link"
  resource_group_name   = data.azurerm_resource_group.spoke.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_blob[0].name
  virtual_network_id    = azurerm_virtual_network.this[0].id
}
