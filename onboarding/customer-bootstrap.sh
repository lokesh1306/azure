#!/usr/bin/env bash
set -euo pipefail

# Pre-spoke prereqs that mirror the AWS manual steps (trust role + state bucket + DNS zone).
# Run this in the *customer* tenant + subscription. Requires az CLI logged into that tenant.
#
# Usage:
#   ENV_NAME=env58 \
#   HUB_OIDC_ISSUER='https://<hub-aks-oidc-url>/' \
#   CLOUD_ENVIRONMENT=commercial \
#   LOCATION=eastus \
#   DOMAIN=env58.stack.ai \
#   ./customer-bootstrap.sh

: "${ENV_NAME:?ENV_NAME required (e.g. env58)}"
: "${HUB_OIDC_ISSUER:?HUB_OIDC_ISSUER required (commercial-Azure AKS hub OIDC issuer URL, trailing slash)}"
: "${CLOUD_ENVIRONMENT:?CLOUD_ENVIRONMENT required: commercial | usgovernment}"
: "${LOCATION:?LOCATION required (e.g. eastus, usgovvirginia)}"
: "${DOMAIN:?DOMAIN required (e.g. env58.stack.ai)}"

ATLANTIS_SA_SUBJECT="${ATLANTIS_SA_SUBJECT:-system:serviceaccount:tools:atlantis}"
APP_REG_NAME="${APP_REG_NAME:-stackai-atlantis-${ENV_NAME}}"
SPOKE_RG_NAME="${SPOKE_RG_NAME:-stackai-${ENV_NAME}-rg}"
STATE_RG_NAME="${ENV_NAME}-tfstate-rg"
STATE_SA_NAME="${ENV_NAME}stackaitfstate"
DNS_RG_NAME="${DNS_RG_NAME:-dns}"

case "$CLOUD_ENVIRONMENT" in
  commercial)   az cloud set --name AzureCloud > /dev/null ;;
  usgovernment) az cloud set --name AzureUSGovernment > /dev/null ;;
  *) echo "Unknown CLOUD_ENVIRONMENT=$CLOUD_ENVIRONMENT" >&2; exit 1 ;;
esac

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "Tenant:       $TENANT_ID"
echo "Subscription: $SUBSCRIPTION_ID"

echo "[1/6] App Registration"
APP_ID=$(az ad app create --display-name "$APP_REG_NAME" --query appId -o tsv)
SP_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv 2>/dev/null || az ad sp show --id "$APP_ID" --query id -o tsv)

echo "[2/6] Federated Identity Credential (trust hub OIDC issuer + atlantis SA)"
FIC_PARAMS=$(jq -n \
  --arg name "atlantis-hub" \
  --arg issuer "$HUB_OIDC_ISSUER" \
  --arg subject "$ATLANTIS_SA_SUBJECT" \
  '{name: $name, issuer: $issuer, subject: $subject, audiences: ["api://AzureADTokenExchange"]}')
az ad app federated-credential create --id "$APP_ID" --parameters "$FIC_PARAMS" >/dev/null

echo "[3/6] Subscription role assignments"
# Contributor = ARM control plane for everything (RG, VNet, AKS, Storage, etc.)
az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
  --role Contributor --scope "/subscriptions/$SUBSCRIPTION_ID" >/dev/null
# User Access Administrator = ability to grant roles (for workload-identity FICs, role assignments on UAMIs, etc.)
az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
  --role "User Access Administrator" --scope "/subscriptions/$SUBSCRIPTION_ID" >/dev/null
# Key Vault Administrator = KV data plane (RBAC mode; subscription Contributor doesn't include data-plane access)
az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
  --role "Key Vault Administrator" --scope "/subscriptions/$SUBSCRIPTION_ID" >/dev/null
# AKS Cluster User Role = ability to fetch kubeconfig (needed by `az aks command invoke`)
az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
  --role "Azure Kubernetes Service Cluster User Role" --scope "/subscriptions/$SUBSCRIPTION_ID" >/dev/null
# AKS RBAC Cluster Admin = K8s API admin via AAD (separate data plane from ARM)
az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
  --role "Azure Kubernetes Service RBAC Cluster Admin" --scope "/subscriptions/$SUBSCRIPTION_ID" >/dev/null

echo "[4/6] Spoke resource group"
az group create --name "$SPOKE_RG_NAME" --location "$LOCATION" >/dev/null

echo "[5/6] State Storage Account + container"
az group create --name "$STATE_RG_NAME" --location "$LOCATION" >/dev/null
az storage account create --name "$STATE_SA_NAME" --resource-group "$STATE_RG_NAME" \
  --location "$LOCATION" --sku Standard_LRS --kind StorageV2 \
  --min-tls-version TLS1_2 --allow-blob-public-access false >/dev/null
az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Owner" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$STATE_RG_NAME/providers/Microsoft.Storage/storageAccounts/$STATE_SA_NAME" >/dev/null
az storage container create --name tfstate --account-name "$STATE_SA_NAME" --auth-mode login >/dev/null

echo "[6/6] Public DNS zone"
az group create --name "$DNS_RG_NAME" --location "$LOCATION" >/dev/null 2>&1 || true
az network dns zone create --name "$DOMAIN" --resource-group "$DNS_RG_NAME" >/dev/null
DNS_ZONE_ID=$(az network dns zone show --name "$DOMAIN" --resource-group "$DNS_RG_NAME" --query id -o tsv)

cat <<EOF

Done. Drop the following into the env.yaml for ${ENV_NAME}:

  tenant_id:             "${TENANT_ID}"
  subscription_id:       "${SUBSCRIPTION_ID}"
  client_id:             "${APP_ID}"
  atlantis_principal_id: "${SP_ID}"
  resource_group_name:   "${SPOKE_RG_NAME}"
  dns_zone_id:           "${DNS_ZONE_ID}"

State backend will use:
  resource_group_name:  ${STATE_RG_NAME}
  storage_account_name: ${STATE_SA_NAME}
  container_name:       tfstate

Delegate ${DOMAIN} NS records at the parent zone to the Azure DNS nameservers shown above.
EOF
