variable "environment" {
  description = "Environment name"
  type        = string
}

variable "resource_group_name" {
  description = "Pre-existing spoke resource group"
  type        = string
}

variable "tenant_id" {
  description = "Entra tenant ID of the spoke subscription"
  type        = string
}

variable "customer_secrets" {
  description = "Map of customer-supplied secrets to materialize as Key Vault secrets."
  type        = map(string)
  sensitive   = true
}

variable "apps_temporal" {
  description = "Create the temporal-secrets KV entry with a generated DB password."
  type        = bool
  default     = true
}

variable "acr_credentials" {
  description = "Container registry credentials (server/username/password) materialized as a single KV secret. Required — apply fails if absent from secrets.yaml."
  type = object({
    server   = string
    username = string
    password = string
  })
  nullable  = false
  sensitive = true
}
