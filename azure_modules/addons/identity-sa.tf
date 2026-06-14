locals {
  workload_identity_sa_command = join(" && ", flatten([
    for k, v in local.addons : [
      "kubectl create namespace ${v.namespace} --dry-run=client -o yaml | kubectl apply -f -",
      "kubectl create serviceaccount ${v.service_account} -n ${v.namespace} --dry-run=client -o yaml | kubectl apply -f -",
      "kubectl annotate serviceaccount ${v.service_account} -n ${v.namespace} azure.workload.identity/client-id=${azurerm_user_assigned_identity.addon[k].client_id} --overwrite",
    ]
  ]))
}

resource "null_resource" "workload_identity_sa" {
  triggers = {
    subscription_id     = var.subscription_id
    resource_group_name = var.resource_group_name
    cluster_name        = var.cluster_name
    command             = local.workload_identity_sa_command
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      WORKDIR=$(mktemp -d)
      trap "rm -rf $WORKDIR" EXIT
      if [ -n "$${ARM_OIDC_TOKEN_FILE_PATH:-}" ]; then
        export AZURE_CONFIG_DIR="$WORKDIR/.azure"
        az login --service-principal -u "$ARM_CLIENT_ID" -t "$ARM_TENANT_ID" --federated-token "$(cat "$ARM_OIDC_TOKEN_FILE_PATH")" --only-show-errors > /dev/null
      fi
      RESULT=$(az aks command invoke \
        --subscription ${self.triggers.subscription_id} \
        --resource-group ${self.triggers.resource_group_name} \
        --name ${self.triggers.cluster_name} \
        --command "${self.triggers.command}" \
        --only-show-errors -o json)
      echo "$RESULT" | python3 -c 'import sys,json; r=json.load(sys.stdin); print(r.get("logs","")); sys.exit(int(r.get("exitCode") or 0))'
    EOT
  }
}
