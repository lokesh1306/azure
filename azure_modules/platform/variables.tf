variable "environment" {
  description = "Environment name"
  type        = string
}

variable "resource_group_name" {
  description = "Pre-existing spoke resource group. Region inherited from the RG."
  type        = string
}

variable "tenant_id" {
  description = "Entra tenant ID of the spoke subscription."
  type        = string
}

variable "subscription_id" {
  description = "Spoke subscription ID."
  type        = string
}

variable "cloud_environment" {
  description = "Azure cloud: \"commercial\" or \"usgovernment\". Drives private DNS zone suffixes."
  type        = string
  default     = "commercial"

  validation {
    condition     = contains(["commercial", "usgovernment"], var.cloud_environment)
    error_message = "cloud_environment must be 'commercial' or 'usgovernment'."
  }
}

variable "private_dns_suffixes" {
  description = "Per-cloud private DNS zone name overrides (keyvault, storage_blob)."
  type = object({
    keyvault     = string
    storage_blob = string
  })
}

variable "vnet_cidr" {
  description = "VNet address space when creating one. Ignored if existing_vnet_id is set."
  type        = string
  default     = "10.50.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for the system node pool. Set to [] for subscriptions/regions without AKS AZ support."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "pod_cidr" {
  description = "Overlay CIDR for AKS pods (Cilium overlay, not in the VNet). Override only if it collides with on-prem / peered networks."
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "Virtual CIDR for K8s Services (cluster-internal, not in the VNet). Override only if it collides with on-prem / peered networks."
  type        = string
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  description = "CoreDNS service IP. Must sit inside service_cidr — typically the .10 of the service CIDR."
  type        = string
  default     = "172.16.0.10"
}

variable "existing_vnet_id" {
  description = "Resource ID of an existing VNet to attach AKS to. When set, no VNet/subnets/NAT are created."
  type        = string
  default     = null
}

variable "existing_aks_subnet_id" {
  description = "Resource ID of the subnet AKS nodes will run in. Required when existing_vnet_id is set."
  type        = string
  default     = null
}

variable "existing_private_endpoint_subnet_id" {
  description = "Resource ID of the subnet for private endpoints (KV, Storage). Required when existing_vnet_id is set."
  type        = string
  default     = null
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version."
  type        = string
  default     = "1.35"
}

variable "admin_group_object_ids" {
  description = "Entra group object IDs granted AKS RBAC cluster-admin via Azure RBAC integration."
  type        = list(string)
  default     = []
}


variable "enable_teleport_agent" {
  description = "Create the Teleport agent UAMI + federated credential (identity-only)."
  type        = bool
  default     = true
}

variable "teleport_agent_namespace" {
  description = "Namespace where teleport-kube-agent runs."
  type        = string
  default     = "teleport"
}

variable "teleport_agent_service_account" {
  description = "ServiceAccount name the teleport-kube-agent pod uses."
  type        = string
  default     = "teleport-kube-agent"
}

variable "logs_retention_days" {
  description = "Log Analytics workspace retention in days."
  type        = number
  default     = 90
}
