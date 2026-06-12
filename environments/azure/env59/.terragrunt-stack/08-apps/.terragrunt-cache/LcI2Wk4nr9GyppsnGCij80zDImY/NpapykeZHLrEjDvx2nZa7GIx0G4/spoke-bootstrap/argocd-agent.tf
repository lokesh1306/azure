locals {
  argocd_namespace = "stackai-addons"

  argocd_compute_values = yamlencode({
    crds           = { install = true }
    server         = { enabled = false }
    dex            = { enabled = false }
    notifications  = { enabled = false }
    applicationSet = { enabled = false }
    controller     = { enabled = true }
    repoServer     = { enabled = true }
    redis          = { enabled = true }
  })

  spiffe_helper_conf = <<-EOF
    agent_address = "/run/spire/agent-sockets/spire-agent.sock"
    cert_dir = "/run/spire/svid"
    svid_file_name = "svid.pem"
    svid_key_file_name = "svid_key.pem"
    svid_bundle_file_name = "svid_bundle.pem"
    cert_file_mode = 0644
    key_file_mode = 0644
    add_intermediates_to_bundle = true
    daemon_mode = true
    renew_signal = "SIGTERM"
    pid_file_name = "/run/spire/svid/argocd-pid"
  EOF

  argocd_agent_manifests = templatefile("${path.module}/templates/argocd-agent.yaml", {
    namespace         = local.argocd_namespace
    trust_domain      = var.trust_domain
    principal_address = split(":", var.hub_principal_endpoint)[0]
    principal_port    = format("%q", split(":", var.hub_principal_endpoint)[1])
  })
}

resource "null_resource" "argocd_agent" {
  triggers = {
    subscription_id     = var.subscription_id
    resource_group_name = var.resource_group_name
    cluster_name        = var.cluster_name
    chart_version       = var.argocd_chart_version
    namespace           = local.argocd_namespace
    compute_hash        = sha256(local.argocd_compute_values)
    helper_hash         = sha256(local.spiffe_helper_conf)
    manifests_hash      = sha256(local.argocd_agent_manifests)
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      WORKDIR=$(mktemp -d)
      trap "rm -rf $WORKDIR" EXIT
      cat > "$WORKDIR/compute-values.yaml" <<'EOVALUES'
${local.argocd_compute_values}
EOVALUES
      cat > "$WORKDIR/helper.conf" <<'EOHELPER'
${local.spiffe_helper_conf}
EOHELPER
      cat > "$WORKDIR/agent.yaml" <<'EOAGENT'
${local.argocd_agent_manifests}
EOAGENT
      az aks command invoke \
        --subscription ${self.triggers.subscription_id} \
        --resource-group ${self.triggers.resource_group_name} \
        --name ${self.triggers.cluster_name} \
        --file "$WORKDIR/compute-values.yaml" \
        --file "$WORKDIR/helper.conf" \
        --file "$WORKDIR/agent.yaml" \
        --command "helm upgrade --install argocd argo-cd --repo https://argoproj.github.io/argo-helm --version ${self.triggers.chart_version} -n ${self.triggers.namespace} --create-namespace -f compute-values.yaml --atomic --timeout 15m && kubectl create configmap spiffe-helper-config -n ${self.triggers.namespace} --from-file=helper.conf=helper.conf --dry-run=client -o yaml | kubectl apply -f - && kubectl apply -f agent.yaml" \
        --only-show-errors
    EOT
  }

  depends_on = [null_resource.spire_agent]
}
