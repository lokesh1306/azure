##################
### Global
##################
variable "project" {
  type        = string
  description = "Project Name"
  default     = "infrastructure"
}

variable "environment" {
  type        = string
  description = "Environment Name"
  default     = "common"
}

variable "resource_group_name" {
  description = "Pre-existing hub resource group. Holds state SA, KV, DNS zone, and everything terraform creates for the hub env."
  type        = string
}

variable "tenant_id" {
  description = "Entra tenant ID of the hub subscription"
  type        = string
}

variable "subscription_id" {
  description = "Hub subscription ID"
  type        = string
}

variable "admin_group_object_ids" {
  description = "Entra group object IDs granted AKS cluster-admin via Azure RBAC."
  type        = list(string)
  default     = []
}

###################
# Networking
###################

variable "vnet_cidr" {
  description = "Hub VNet CIDR"
  type        = string
}

###################
# AKS
###################

variable "kubernetes_version" {
  description = "AKS Kubernetes version"
  type        = string
}

###################
# DNS
###################

variable "domain_name" {
  description = "Hub domain (e.g. ops.stack.ai)"
  type        = string
}

variable "dns_zone_id" {
  description = "Resource ID of the manually-created public Azure DNS zone for the hub domain."
  type        = string
}

###################
# Hub Key Vault (manually created)
###################

variable "argocd_secrets_kv_uri" {
  description = "URI of the hub Key Vault holding ArgoCD SSO secret (named common-argocd-secrets). Created manually."
  type        = string
}

variable "hub_spire_endpoint" {
  description = "Hub SPIRE server address:port the spoke agent attests to."
  type        = string
  default     = "spire.ops.stack.ai:443"
}

variable "hub_principal_endpoint" {
  description = "Hub argocd-agent principal address:port the spoke agent dials."
  type        = string
  default     = "grpc.ops.stack.ai:443"
}

variable "hub_trust_bundle" {
  description = "Hub SPIRE trust bundle (bundle.spiffe), seeded into the spire-bundle ConfigMap."
  type        = string
}
