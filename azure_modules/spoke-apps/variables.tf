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
  description = "Spoke Key Vault resource ID (from 06-secrets). Used by external-secrets and stackai-apps."
  type        = string
  default     = null
}

variable "admin_email" {
  description = "Admin email passed to stackai-apps."
  type        = string
  default     = ""
}

variable "org_name" {
  description = "Organization/customer name passed to stackai-apps."
  type        = string
}

variable "acr_credentials_secret_name" {
  description = "Key Vault secret name with ACR registry credentials, projected onto the spoke as an argocd repository secret. Null skips it."
  type        = string
  default     = null
}

variable "acr_credentials_secret_version" {
  description = "Current version of the ACR credentials KV secret (from 06-secrets). Used as the re-apply trigger so the spoke repository secret rotates only when the KV secret changes."
  type        = string
  default     = null
}

variable "apps" {
  description = "Feature flags for which app infrastructure to provision"
  type = object({
    supabase       = optional(bool, true)
    mongodb        = optional(bool, true)
    weaviate       = optional(bool, true)
    unstructured   = optional(bool, true)
    parser_service = optional(bool, true)
  })
  default = {}
}

variable "supabase_config" {
  description = "Supabase-specific configuration"
  type = object({
    use_external_db = optional(bool, false)
    use_s3_storage  = optional(bool, false)
    enable_saml     = optional(bool, false)
  })
  default = {}
}

variable "dns_zone_id" {
  description = "Azure DNS public zone resource ID for external-dns/cert-manager."
  type        = string
  nullable    = false
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
