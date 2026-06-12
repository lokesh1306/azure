locals {
  spire_namespace = "spire-system"

  spire_values_yaml = <<-YAML
    global:
      installAndUpgradeHooks:
        enabled: false
      deleteHooks:
        enabled: false
      spire:
        trustDomain: ${var.trust_domain}
        clusterName: ${var.cluster_name}
        bundleConfigMap: spire-bundle
        namespaces:
          create: false
    spire-server:
      enabled: false
    spiffe-oidc-discovery-provider:
      enabled: false
    spire-agent:
      image:
        tag: "1.15.1"
      logLevel: INFO
      rebootstrapMode: never
      server:
        address: ${split(":", var.hub_spire_endpoint)[0]}
        port: ${split(":", var.hub_spire_endpoint)[1]}
      nodeAttestor:
        k8sPSAT:
          enabled: false
      unsupportedBuiltInPlugins:
        nodeAttestor:
          azure_imds:
            plugin_data:
              tenant_domain: "${var.tenant_domain}"
      workloadAttestors:
        k8s:
          enabled: true
          disableContainerSelectors: true
      persistence:
        type: hostPath
        hostPath: /var/lib/spire/k8s/agent
      keyManager:
        memory:
          enabled: false
        disk:
          enabled: true
    spiffe-csi-driver:
      enabled: true
      agentSocketPath: /run/spire/agent-sockets/spire-agent.sock
  YAML
}

resource "null_resource" "spire_agent" {
  triggers = {
    subscription_id     = var.subscription_id
    resource_group_name = var.resource_group_name
    cluster_name        = var.cluster_name
    chart_version       = var.spire_chart_version
    values_hash         = sha256(local.spire_values_yaml)
    bundle_hash         = sha256(var.hub_trust_bundle)
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      WORKDIR=$(mktemp -d)
      trap "rm -rf $WORKDIR" EXIT
      cat > "$WORKDIR/values.yaml" <<'EOVALUES'
${local.spire_values_yaml}
EOVALUES
      cat > "$WORKDIR/bundle.spiffe" <<'EOBUNDLE'
${var.hub_trust_bundle}
EOBUNDLE
      RESULT=$(az aks command invoke \
        --subscription ${self.triggers.subscription_id} \
        --resource-group ${self.triggers.resource_group_name} \
        --name ${self.triggers.cluster_name} \
        --file "$WORKDIR/values.yaml" \
        --file "$WORKDIR/bundle.spiffe" \
        --command "kubectl create namespace ${local.spire_namespace} --dry-run=client -o yaml | kubectl apply -f - && kubectl create configmap spire-bundle -n ${local.spire_namespace} --from-file=bundle.spiffe=bundle.spiffe --dry-run=client -o yaml | kubectl apply -f - && helm upgrade --install spire spire --repo https://spiffe.github.io/helm-charts-hardened --version ${self.triggers.chart_version} -n ${local.spire_namespace} -f values.yaml --wait --atomic --timeout 10m" \
        --only-show-errors -o json)
      echo "$RESULT" | python3 -c 'import sys,json; r=json.load(sys.stdin); print(r.get("logs","")); sys.exit(int(r.get("exitCode") or 0))'
    EOT
  }
}
