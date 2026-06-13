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
  description = "Enable Parser Service (creates the blob storage account + workload identity + parser secret)."
  type        = bool
  default     = false
}

variable "parser_service_retention_days" {
  description = "Days before parser uploads are auto-deleted from the storage container."
  type        = number
  default     = 7
}

variable "enable_mongodb" {
  description = "Enable MongoDB (creates the MongoDB credentials secret)."
  type        = bool
  default     = false
}

variable "enable_weaviate" {
  description = "Enable Weaviate (creates the Weaviate API key secret)."
  type        = bool
  default     = false
}

variable "enable_unstructured" {
  description = "Enable Unstructured (creates the Unstructured API key secret)."
  type        = bool
  default     = false
}

variable "enable_supabase" {
  description = "Enable Supabase (creates the Supabase secrets; storage when supabase_use_s3_storage)."
  type        = bool
  default     = false
}

variable "supabase_use_s3_storage" {
  description = "Use Azure Blob storage for Supabase storage backend (Azure analogue of supabase_use_s3_storage)."
  type        = bool
  default     = false
}

variable "supabase_use_external_db" {
  description = "Whether Supabase points at an external/managed Postgres. Azure skips the managed DB cloud resources but keeps the DB secrets."
  type        = bool
  default     = false
}

variable "supabase_enable_saml" {
  description = "Generate the Supabase SAML private key (GoTrue SAML)."
  type        = bool
  default     = false
}
