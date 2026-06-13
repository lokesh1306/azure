variable "environment" {
  description = "Environment name"
  type        = string
}

variable "resource_group_name" {
  description = "Spoke resource group."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "AKS OIDC issuer URL (from platform module)."
  type        = string
}

variable "key_vault_id" {
  description = "Resource ID of a Key Vault to grant external-secrets read access. Optional — when null, the external-secrets identity is still created but no KV role is bound."
  type        = string
  default     = null
}

variable "dns_zone_id" {
  description = "Resource ID of an Azure DNS public zone. external-dns and cert-manager get DNS Zone Contributor on it. Optional — when null, the identities are still created but no DNS role is bound."
  type        = string
  default     = null
}

variable "cluster_name" {
  description = "AKS cluster name. Used by `az aks command invoke` to apply NodePool CRDs."
  type        = string
}

variable "subscription_id" {
  description = "Spoke subscription ID, passed to `az aks command invoke --subscription`."
  type        = string
}

variable "enable_optimized_nodepool" {
  description = "Apply the additional `optimized` NodePool with spot capacity. Mirrors AWS Karpenter optional optimized_nodepool."
  type        = bool
  default     = true
}

variable "optimized_nodepool_spec" {
  description = "Full replacement for the optimized NodePool `spec` (weight, limits, template, disruption). Null uses the module default."
  type        = any
  default     = null
}
