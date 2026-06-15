resource "azurerm_kubernetes_cluster" "this" {
  name                = "${var.environment}-aks"
  resource_group_name = data.azurerm_resource_group.spoke.name
  location            = data.azurerm_resource_group.spoke.location
  dns_prefix          = "${var.environment}-aks"
  kubernetes_version  = var.kubernetes_version

  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = false

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  node_provisioning_profile {
    mode = "Auto"
  }

  azure_active_directory_role_based_access_control {
    tenant_id              = var.tenant_id
    admin_group_object_ids = var.admin_group_object_ids
    azure_rbac_enabled     = true
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    outbound_type       = "userAssignedNATGateway"
    load_balancer_sku   = "standard"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
  }

  default_node_pool {
    name            = "system"
    vm_size         = var.system_vm_size
    vnet_subnet_id  = local.aks_subnet_id
    node_count      = 2
    zones           = var.availability_zones
    os_disk_size_gb = 50
    os_disk_type    = "Managed"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  monitor_metrics {}

  depends_on = [
    azurerm_subnet_nat_gateway_association.aks,
  ]
}

resource "azurerm_role_assignment" "admin_group_rbac_cluster_admin" {
  for_each = toset(var.admin_group_object_ids)

  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = each.value
  principal_type       = "Group"
}

resource "azurerm_role_assignment" "aks_vnet_network_contributor" {
  scope                = local.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "runner_aks_rbac_cluster_admin" {
  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}
