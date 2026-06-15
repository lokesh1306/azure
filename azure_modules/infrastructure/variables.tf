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
  description = "Azure cloud: 'commercial' or 'usgovernment'."
  type        = string
  default     = "commercial"
}

variable "private_dns_suffixes" {
  description = "Per-cloud private DNS zone names."
  type = object({
    keyvault     = string
    storage_blob = string
  })
}

variable "vnet_cidr" {
  description = "VNet CIDR when creating one."
  type        = string
  default     = "10.50.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for the system node pool. Set to [] for subscriptions/regions without AKS AZ support."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "pod_cidr" {
  description = "Overlay CIDR for AKS pods."
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "Virtual CIDR for K8s Services."
  type        = string
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  description = "CoreDNS service IP. Must sit inside service_cidr."
  type        = string
  default     = "172.16.0.10"
}

variable "existing_vnet_id" {
  description = "Resource ID of an existing VNet; when set, no VNet/subnets/NAT are created."
  type        = string
  default     = null
}

variable "existing_aks_subnet_id" {
  description = "Required when existing_vnet_id is set."
  type        = string
  default     = null
}

variable "existing_private_endpoint_subnet_id" {
  description = "Required when existing_vnet_id is set."
  type        = string
  default     = null
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version."
  type        = string
  default     = "1.31"
}

variable "admin_group_object_ids" {
  description = "Entra group object IDs granted AKS cluster-admin."
  type        = list(string)
  default     = []
}

