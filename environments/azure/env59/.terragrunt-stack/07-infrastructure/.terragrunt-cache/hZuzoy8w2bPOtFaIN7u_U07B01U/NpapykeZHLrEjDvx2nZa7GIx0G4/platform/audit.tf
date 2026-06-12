resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.environment}-law"
  resource_group_name = data.azurerm_resource_group.spoke.name
  location            = data.azurerm_resource_group.spoke.location
  sku                 = "PerGB2018"
  retention_in_days   = var.logs_retention_days
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "${var.environment}-aks-diag"
  target_resource_id         = azurerm_kubernetes_cluster.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log { category = "kube-apiserver" }
  enabled_log { category = "kube-audit" }
  enabled_log { category = "kube-audit-admin" }
  enabled_log { category = "kube-controller-manager" }
  enabled_log { category = "kube-scheduler" }
  enabled_log { category = "cluster-autoscaler" }
  enabled_log { category = "guard" }

  enabled_metric { category = "AllMetrics" }
}
