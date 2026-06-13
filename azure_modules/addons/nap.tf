locals {
  default_optimized_nodepool_yaml = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: optimized
    spec:
      weight: 50
      limits:
        cpu: 256
        memory: 1024Gi
      template:
        spec:
          nodeClassRef:
            group: karpenter.azure.com
            kind: AKSNodeClass
            name: default
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: karpenter.azure.com/sku-family
              operator: In
              values: ["D", "E", "F"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot", "on-demand"]
            - key: karpenter.azure.com/sku-cpu
              operator: In
              values: ["16", "32", "48", "64"]
          expireAfter: 336h
          terminationGracePeriod: 1m
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 5m
        budgets:
          - nodes: "20%"
  YAML

  optimized_nodepool_yaml = var.optimized_nodepool_spec != null ? yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata   = { name = "optimized" }
    spec       = var.optimized_nodepool_spec
  }) : local.default_optimized_nodepool_yaml
}

resource "null_resource" "optimized_nodepool" {
  count = var.enable_optimized_nodepool ? 1 : 0

  triggers = {
    cluster_name        = var.cluster_name
    resource_group_name = var.resource_group_name
    yaml_hash           = sha256(local.optimized_nodepool_yaml)
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      WORKDIR=$(mktemp -d)
      trap "rm -rf $WORKDIR" EXIT
      cat > "$WORKDIR/optimized-nodepool.yaml" <<'EOYAML'
${local.optimized_nodepool_yaml}
EOYAML
      if [ -n "$${ARM_OIDC_TOKEN_FILE_PATH:-}" ]; then
        export AZURE_CONFIG_DIR="$WORKDIR/.azure"
        az login --service-principal -u "$ARM_CLIENT_ID" -t "$ARM_TENANT_ID" --federated-token "$(cat "$ARM_OIDC_TOKEN_FILE_PATH")" --only-show-errors > /dev/null
      fi
      az aks command invoke \
        --resource-group ${self.triggers.resource_group_name} \
        --name ${self.triggers.cluster_name} \
        --file "$WORKDIR/optimized-nodepool.yaml" \
        --command "kubectl apply -f optimized-nodepool.yaml" \
        --only-show-errors
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "az aks command invoke --resource-group ${self.triggers.resource_group_name} --name ${self.triggers.cluster_name} --command 'kubectl delete nodepool optimized --ignore-not-found' --only-show-errors || true"
  }
}
