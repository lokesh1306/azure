locals {
  acr_enabled = var.acr_credentials_secret_name != null && var.key_vault_id != null
}

data "azurerm_key_vault_secret" "acr_credentials" {
  count        = local.acr_enabled ? 1 : 0
  name         = var.acr_credentials_secret_name
  key_vault_id = var.key_vault_id
}

locals {
  acr_credentials = local.acr_enabled ? jsondecode(data.azurerm_key_vault_secret.acr_credentials[0].value) : null

  acr_helm_repo_manifest = !local.acr_enabled ? "" : yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "acr-helm-repo"
      namespace = local.argocd_namespace
      labels    = { "argocd.argoproj.io/secret-type" = "repository" }
    }
    stringData = {
      type      = "helm"
      name      = "stackai-acr"
      url       = local.acr_credentials.server
      enableOCI = "true"
      username  = local.acr_credentials.username
      password  = local.acr_credentials.password
    }
  })
}

resource "null_resource" "acr_helm_repo" {
  count = local.acr_enabled ? 1 : 0

  triggers = {
    subscription_id     = var.subscription_id
    resource_group_name = var.resource_group_name
    cluster_name        = var.cluster_name
    namespace           = local.argocd_namespace
    # Re-apply only when the KV secret rotates (new version), not every run.
    acr_secret_version = data.azurerm_key_vault_secret.acr_credentials[0].version
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      WORKDIR=$(mktemp -d)
      trap "rm -rf $WORKDIR" EXIT
      cat > "$WORKDIR/acr-helm-repo.yaml" <<'EOMANIFEST'
${local.acr_helm_repo_manifest}
EOMANIFEST
      if [ -n "$${ARM_OIDC_TOKEN_FILE_PATH:-}" ]; then
        export AZURE_CONFIG_DIR="$WORKDIR/.azure"
        az login --service-principal -u "$ARM_CLIENT_ID" -t "$ARM_TENANT_ID" --federated-token "$(cat "$ARM_OIDC_TOKEN_FILE_PATH")" --only-show-errors > /dev/null
      fi
      RESULT=$(az aks command invoke \
        --subscription ${self.triggers.subscription_id} \
        --resource-group ${self.triggers.resource_group_name} \
        --name ${self.triggers.cluster_name} \
        --file "$WORKDIR/acr-helm-repo.yaml" \
        --command "kubectl create namespace ${self.triggers.namespace} --dry-run=client -o yaml | kubectl apply -f - && kubectl apply -f acr-helm-repo.yaml" \
        --only-show-errors -o json)
      echo "$RESULT" | python3 -c 'import sys,json; r=json.load(sys.stdin); print(r.get("logs","")); sys.exit(int(r.get("exitCode") or 0))'
    EOT
  }

  depends_on = [null_resource.argocd_agent]
}
