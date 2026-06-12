#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Generate an Azure spoke environment from template.
# Usage:
#   ./scripts/generate-azure.sh <env-name>
# Example:
#   ./scripts/generate-azure.sh env59
#
# Scaffolds environments/azure/<env-name>/ wiring the platform(aks) + addons +
# spoke-bootstrap(spire + argocd-agent) modules via the units/azure/external
# terragrunt stack, plus the gitops manifests (teleport-kube-agent, test-podinfo)
# delivered to the spoke through the hub argocd-agent.
#
# After generating: fill the spoke-specific values in env.yaml, then create the
# hub-side artifacts in spokes/<env-name>/ (run with --with-spokes to scaffold
# them too).
# =============================================================================

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE_DIR="${REPO_ROOT}/templates/azure/external"

WITH_SPOKES=0
ENV_NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-spokes) WITH_SPOKES=1; shift ;;
    -h|--help) sed -n '4,16p' "$0" | sed 's/^# \?//'; exit 0 ;;
    -*) echo "Unknown flag: $1" >&2; exit 1 ;;
    *)
      if [[ -z "${ENV_NAME}" ]]; then ENV_NAME="$1"; else echo "Unexpected arg: $1" >&2; exit 1; fi
      shift ;;
  esac
done

if [[ -z "${ENV_NAME}" ]]; then
  echo "Usage: $0 <env-name> [--with-spokes]" >&2
  exit 1
fi
if [[ ! "${ENV_NAME}" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "ERROR: env name must be lowercase alphanumeric with hyphens (e.g. 'env59')" >&2
  exit 1
fi

ENV_DIR="${REPO_ROOT}/environments/azure/${ENV_NAME}"
if [[ -d "${ENV_DIR}" ]]; then
  echo "ERROR: environment '${ENV_NAME}' already exists at ${ENV_DIR}" >&2
  exit 1
fi

if sed --version >/dev/null 2>&1; then SED_INPLACE=(sed -i); else SED_INPLACE=(sed -i ''); fi

echo "=============================================="
echo "Generating Azure spoke: ${ENV_NAME}"
echo "=============================================="

mkdir -p "${ENV_DIR}"

# env.yaml + terragrunt.stack.hcl
sed -e "s/__ENV_NAME__/${ENV_NAME}/g" "${TEMPLATE_DIR}/env.yaml" > "${ENV_DIR}/env.yaml"
cp "${TEMPLATE_DIR}/terragrunt.stack.hcl" "${ENV_DIR}/terragrunt.stack.hcl"
echo "✓ env.yaml + terragrunt.stack.hcl"

# gitops manifests (delivered to the spoke via the hub argocd-agent)
cp -r "${TEMPLATE_DIR}/argocd/manifests" "${ENV_DIR}/manifests"
find "${ENV_DIR}/manifests" -type f \( -name "*.yaml" -o -name "*.yml" \) -print0 \
  | xargs -0 "${SED_INPLACE[@]}" -e "s/__ENV_NAME__/${ENV_NAME}/g"
echo "✓ manifests ($(find "${ENV_DIR}/manifests" -type f | wc -l | tr -d ' ') files)"

# hub-side per-spoke artifacts (applied manually to the hub)
if [[ "${WITH_SPOKES}" -eq 1 && -d "${REPO_ROOT}/templates/azure/spokes" ]]; then
  SPOKE_DIR="${REPO_ROOT}/spokes/${ENV_NAME}"
  mkdir -p "${SPOKE_DIR}"
  cp "${REPO_ROOT}/templates/azure/spokes/"*.yaml "${SPOKE_DIR}/" 2>/dev/null || true
  find "${SPOKE_DIR}" -type f -name "*.yaml" -print0 \
    | xargs -0 "${SED_INPLACE[@]}" -e "s/__ENV_NAME__/${ENV_NAME}/g"
  echo "✓ spokes/${ENV_NAME} (hub-side; fill subscription/RG/OIDC placeholders before applying)"
fi

echo ""
echo "Next:"
echo "  1. Fill spoke values in environments/azure/${ENV_NAME}/env.yaml"
echo "     (tenant_id, subscription_id, client_id, atlantis_principal_id, hub_trust_bundle)"
echo "  2. Ensure RG '${ENV_NAME}' + storage account '${ENV_NAME}stackaitfstate' exist."
echo "  3. terragrunt stack run apply in environments/azure/${ENV_NAME}"
echo "  4. Apply spokes/${ENV_NAME}/*.yaml to the hub (after the cluster's OIDC issuer is known)."
