variable "environment" {
  description = "Environment name."
  type        = string
}

variable "resource_group_name" {
  description = "Spoke resource group (holds the AKS cluster)."
  type        = string
}

variable "subscription_id" {
  description = "Spoke subscription ID. Passed to `az aks command invoke --subscription` so it targets the spoke cluster regardless of the az CLI default context."
  type        = string
}

variable "cluster_name" {
  description = "AKS cluster name. Becomes the SPIRE clusterName and the agent identity segment in spiffe:// URIs."
  type        = string
}

variable "trust_domain" {
  description = "SPIRE trust domain — must match the hub's."
  type        = string
  default     = "stack.ai"
}

variable "tenant_domain" {
  description = "Entra tenant domain the spoke attests under (azure_imds nodeAttestor). Must match a tenant configured on the hub SPIRE server."
  type        = string
  default     = "StackAIntelligence.onmicrosoft.com"
}

variable "hub_spire_endpoint" {
  description = "Hub SPIRE Server external endpoint, host:port. Spoke SPIRE Agents dial this outbound on 443."
  type        = string
}

variable "hub_principal_endpoint" {
  description = "Hub argocd-agent principal external endpoint, host:port. Spoke agent dials outbound on 443."
  type        = string
}

variable "hub_trust_bundle" {
  description = "Hub SPIRE Server trust bundle (bundle.spiffe). Seeded into the spire-bundle ConfigMap. Public material, not a credential."
  type        = string
}

variable "spire_chart_version" {
  type    = string
  default = "0.28.4"
}

variable "argocd_chart_version" {
  type    = string
  default = "9.5.12"
}

variable "key_vault_id" {
  description = "Spoke Key Vault resource ID (from 06-secrets). Required to read the ACR credentials secret."
  type        = string
  default     = null
}

variable "acr_credentials_secret_name" {
  description = "Key Vault secret name holding ACR registry credentials. Read at apply and projected onto the spoke as an argocd `repository` secret (acr-helm-repo) so the spoke argo-cd repo-server can pull OCI charts. Null skips it."
  type        = string
  default     = null
}
