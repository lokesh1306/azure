locals {
  base_domain = "stack.ai"

  hub_tenant_id       = "REPLACE_WITH_HUB_TENANT_ID"
  hub_subscription_id = "REPLACE_WITH_HUB_SUBSCRIPTION_ID"
  hub_aks_oidc_issuer = "https://REPLACE_WITH_HUB_AKS_OIDC_ISSUER_URL/"
  atlantis_namespace  = "tools"
  atlantis_sa_name    = "atlantis"

  cloud_environments = {
    commercial = {
      provider_environment   = "public"
      arm_endpoint           = "https://management.azure.com/"
      aad_endpoint           = "https://login.microsoftonline.com/"
      storage_blob_dns       = "privatelink.blob.core.windows.net"
      keyvault_dns           = "privatelink.vaultcore.azure.net"
      acr_dns                = "privatelink.azurecr.io"
      cognitive_services_dns = "privatelink.cognitiveservices.azure.com"
    }
    usgovernment = {
      provider_environment   = "usgovernment"
      arm_endpoint           = "https://management.usgovcloudapi.net/"
      aad_endpoint           = "https://login.microsoftonline.us/"
      storage_blob_dns       = "privatelink.blob.core.usgovcloudapi.net"
      keyvault_dns           = "privatelink.vaultcore.usgovcloudapi.net"
      acr_dns                = "privatelink.azurecr.us"
      cognitive_services_dns = "privatelink.cognitiveservices.azure.us"
    }
  }
}
