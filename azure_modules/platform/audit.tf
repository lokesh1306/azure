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

resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "${var.environment}-activity-log"
  target_resource_id         = data.azurerm_subscription.current.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log { category = "Administrative" }
  enabled_log { category = "Security" }
  enabled_log { category = "Policy" }
  enabled_log { category = "Alert" }
  enabled_log { category = "ServiceHealth" }
  enabled_log { category = "ResourceHealth" }
  enabled_log { category = "Autoscale" }
  enabled_log { category = "Recommendation" }
}
