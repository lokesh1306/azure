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
  description = "AKS OIDC issuer URL."
  type        = string
}

variable "key_vault_id" {
  description = "Spoke Key Vault resource ID."
  type        = string
}

variable "admin_email" {
  description = "Admin email for app config."
  type        = string
}

variable "org_name" {
  description = "Organization/customer name."
  type        = string
}

variable "enable_parser_service" {
  type    = bool
  default = false
}

variable "parser_service_retention_days" {
  type    = number
  default = 7
}

variable "enable_mongodb" {
  type    = bool
  default = false
}

variable "enable_weaviate" {
  type    = bool
  default = false
}

variable "enable_unstructured" {
  type    = bool
  default = false
}

variable "enable_supabase" {
  type    = bool
  default = false
}

variable "supabase_use_s3_storage" {
  description = "Use Azure Blob storage for Supabase storage backend (Azure analogue of supabase_use_s3_storage)."
  type        = bool
  default     = false
}
