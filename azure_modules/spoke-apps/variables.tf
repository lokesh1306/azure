variable "environment" {
  description = "Environment name"
  type        = string
}

variable "resource_group_name" {
  description = "Pre-existing spoke resource group. Region inherited from the RG."
  type        = string
}

variable "subscription_id" {
  description = "Spoke subscription ID (passed to spoke-bootstrap for az aks command invoke targeting)."
  type        = string
}

variable "cluster_name" {
  description = "AKS cluster name."
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "AKS OIDC issuer URL."
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault resource ID for external-secrets (optional)."
  type        = string
  default     = null
}

variable "dns_zone_id" {
  description = "Azure DNS public zone resource ID for external-dns/cert-manager (optional)."
  type        = string
  default     = null
}

variable "enable_optimized_nodepool" {
  description = "Apply the optimized NodePool (on-demand + spot). Mirrors the AWS Karpenter optimized_nodepool toggle."
  type        = bool
  default     = true
}

variable "optimized_nodepool_spec" {
  description = "Full replacement for the optimized NodePool spec. Null uses the addons module default."
  type        = any
  default     = null
}

variable "spoke_bootstrap" {
  description = "SPIRE + argocd-agent spoke bootstrap configuration."
  type = object({
    trust_domain           = string
    tenant_domain          = optional(string, "StackAIntelligence.onmicrosoft.com")
    hub_spire_endpoint     = string
    hub_principal_endpoint = string
    hub_trust_bundle       = string
  })
}
