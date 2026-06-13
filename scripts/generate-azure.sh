#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Generate an Azure spoke environment from template
# Usage:
#   ./scripts/generate-azure.sh <env-name>
# Examples:
#   ./scripts/generate-azure.sh env61
# Region is not set here — every resource inherits its location from the
# pre-created spoke resource group.
# =============================================================================

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES_DIR="${REPO_ROOT}/templates/azure"

PLATFORM="${PLATFORM:-byoc}"

ENV_NAME=""
EMAIL=""
WITH_SPOKES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --email)       EMAIL="$2"; shift 2 ;;
    --with-spokes) WITH_SPOKES=1; shift ;;
    -h|--help)
      sed -n '4,12p' "$0" | sed 's/^# \?//'; exit 0 ;;
    -*)            echo "Unknown flag: $1" >&2; exit 1 ;;
    *)
      if [[ -z "${ENV_NAME}" ]]; then ENV_NAME="$1"
      else echo "Unexpected positional arg: $1" >&2; exit 1
      fi
      shift ;;
  esac
done

if [[ -z "${ENV_NAME}" ]]; then
  echo "Usage: $0 <env-name> [--email <email>] [--with-spokes]" >&2
  exit 1
fi

EMAIL="${EMAIL:-devops+${ENV_NAME}@stack-ai.com}"

ENV_DIR="${REPO_ROOT}/environments/azure/${ENV_NAME}"
MANIFEST_TEMPLATE_DIR="${TEMPLATES_DIR}/argocd/manifests"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if [[ -d "${ENV_DIR}" ]]; then
  echo "ERROR: Environment '${ENV_NAME}' already exists at ${ENV_DIR}" >&2
  echo "       Delete it first if you want to regenerate." >&2
  exit 1
fi

if [[ ! -d "${MANIFEST_TEMPLATE_DIR}" ]]; then
  echo "ERROR: Manifest template dir not found at ${MANIFEST_TEMPLATE_DIR}" >&2
  exit 1
fi

# Validate env name (lowercase, alphanumeric, hyphens only)
if [[ ! "${ENV_NAME}" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "ERROR: Environment name must be lowercase alphanumeric with hyphens (e.g., 'env61')" >&2
  exit 1
fi

if ! command -v sops >/dev/null 2>&1; then
  echo "ERROR: sops not found in PATH (needed to decrypt templates/azure/secrets.yaml)" >&2
  exit 1
fi

# Verify the SOPS key is accessible before generating any files by decrypting
# the template secrets baseline.
SOPS_CONFIG="${REPO_ROOT}/.sops.yaml"
if [[ ! -f "${SOPS_CONFIG}" ]]; then
  echo "ERROR: .sops.yaml not found at ${SOPS_CONFIG}" >&2
  exit 1
fi

echo "Checking SOPS key accessibility..."
if ! SOPS_ERR="$(sops -d "${TEMPLATES_DIR}/secrets.yaml" 2>&1 >/dev/null)"; then
  echo "ERROR: SOPS key is not accessible with your current credentials." >&2
  echo "       Ensure you are authenticated to the account that owns the key in .sops.yaml." >&2
  echo "" >&2
  echo "--- sops output ---" >&2
  echo "${SOPS_ERR}" >&2
  exit 1
fi
echo "✓ SOPS key accessible"

echo "=============================================="
echo "Generating Azure spoke: ${ENV_NAME}"
echo "  Platform:   ${PLATFORM}"
echo "  Email:      ${EMAIL}"
echo "=============================================="
echo ""

if sed --version >/dev/null 2>&1; then
  SED_INPLACE=(sed -i)
else
  SED_INPLACE=(sed -i '')
fi
sed_inplace() { "${SED_INPLACE[@]}" "$@"; }

# ---------------------------------------------------------------------------
# 1. Create environment directory
# ---------------------------------------------------------------------------
mkdir -p "${ENV_DIR}"

# ---------------------------------------------------------------------------
# 2. Generate env.yaml from template
# ---------------------------------------------------------------------------
sed -e "s/__ENV_NAME__/${ENV_NAME}/g" "${TEMPLATES_DIR}/env.yaml" > "${ENV_DIR}/env.yaml"
sed_inplace -e "s|^email: .*|email: ${EMAIL}|" "${ENV_DIR}/env.yaml"
echo "✓ Created env.yaml"

# ---------------------------------------------------------------------------
# 3. Generate secrets.yaml baseline from template
# ---------------------------------------------------------------------------
PLAINTEXT_SECRETS="$(mktemp)"
trap 'rm -f "${PLAINTEXT_SECRETS}"' EXIT
sops -d "${TEMPLATES_DIR}/secrets.yaml" > "${PLAINTEXT_SECRETS}"
mv "${PLAINTEXT_SECRETS}" "${ENV_DIR}/secrets.yaml"
trap - EXIT
sops -e -i "${ENV_DIR}/secrets.yaml"
echo "✓ Created secrets.yaml (encrypted, baseline values pre-filled from template)"

# ---------------------------------------------------------------------------
# 4. Generate terragrunt.stack.hcl from template
# ---------------------------------------------------------------------------
cp "${TEMPLATES_DIR}/terragrunt.stack.hcl" "${ENV_DIR}/terragrunt.stack.hcl"
echo "✓ Created terragrunt.stack.hcl"

# ---------------------------------------------------------------------------
# 5. Generate Argo CD manifests from templates/azure/argocd/manifests/
# ---------------------------------------------------------------------------
echo ""
echo "Generating Argo CD manifests..."
cp -r "${MANIFEST_TEMPLATE_DIR}" "${ENV_DIR}/manifests"

find "${ENV_DIR}/manifests" -type f \( -name "*.yaml" -o -name "*.yml" \) -print0 | xargs -0 "${SED_INPLACE[@]}" \
  -e "s/__ENV_NAME__/${ENV_NAME}/g" \
  -e "s/__PLATFORM__/${PLATFORM}/g" \
  -e "s|__EMAIL__|${EMAIL}|g"

MANIFEST_COUNT=$(find "${ENV_DIR}/manifests" -type f \( -name "*.yaml" -o -name "*.yml" \) | wc -l | tr -d ' ')
echo "✓ Generated ${MANIFEST_COUNT} manifest files at environments/azure/${ENV_NAME}/manifests/"

# ---------------------------------------------------------------------------
# 6. Hub-side per-spoke artifacts (Azure-specific; applied manually to the hub)
# ---------------------------------------------------------------------------
if [[ "${WITH_SPOKES}" -eq 1 && -d "${REPO_ROOT}/templates/azure/spokes" ]]; then
  SPOKE_DIR="${REPO_ROOT}/spokes/${ENV_NAME}"
  mkdir -p "${SPOKE_DIR}"
  cp "${REPO_ROOT}/templates/azure/spokes/"*.yaml "${SPOKE_DIR}/" 2>/dev/null || true
  find "${SPOKE_DIR}" -type f -name "*.yaml" -print0 | xargs -0 "${SED_INPLACE[@]}" -e "s/__ENV_NAME__/${ENV_NAME}/g"
  echo "✓ Generated spokes/${ENV_NAME} (hub-side; fill subscription/RG/OIDC placeholders before applying)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "Environment '${ENV_NAME}' generated successfully!"
echo "=============================================="
echo ""
echo "Next steps:"
echo ""
echo "  1. Fill spoke values in environments/azure/${ENV_NAME}/env.yaml"
echo "     (tenant_id, subscription_id, client_id)."
echo ""
echo "  2. Add env-specific secrets to environments/azure/${ENV_NAME}/secrets.yaml. To edit:"
echo ""
echo "       a. Decrypt:    sops -d -i environments/azure/${ENV_NAME}/secrets.yaml"
echo "       b. Edit values (customer.*, infra.acr.username/password)"
echo "       c. Re-encrypt: sops -e -i environments/azure/${ENV_NAME}/secrets.yaml"
echo ""
echo "  3. Ensure RG + storage account '${ENV_NAME}stackaitfstate' exist."
echo ""
echo "  4. Open a PR (Atlantis runs terragrunt stack plan/apply)."
echo ""
