#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Generate an Azure spoke environment from template
# Usage:
#   ./scripts/generate-azure.sh <env-name> [flags]
# Required flags:
#   --subscription-id <guid>      spoke subscription id
#   --tenant-id <guid>            spoke Entra tenant id
#   --client-id <guid>            Atlantis app (client) id for the spoke's tenant
#   --dns-resource-group <name>   resource group holding the spoke's DNS zone
# Optional flags:
#   --email <addr>                contact email (default devops+<env>@stack-ai.com)
# Region is not set here — every resource inherits its location from the
# pre-created spoke resource group. Domain is derived as <env>.stack.ai.
# =============================================================================

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES_DIR="${REPO_ROOT}/templates/azure"
BASE_DOMAIN="stack.ai"

PLATFORM="${PLATFORM:-byoc}"

ENV_NAME=""
EMAIL=""
TENANT_ID=""
SUBSCRIPTION_ID=""
CLIENT_ID=""
DNS_RESOURCE_GROUP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --email)              EMAIL="$2"; shift 2 ;;
    --tenant-id)          TENANT_ID="$2"; shift 2 ;;
    --subscription-id)    SUBSCRIPTION_ID="$2"; shift 2 ;;
    --client-id)          CLIENT_ID="$2"; shift 2 ;;
    --dns-resource-group) DNS_RESOURCE_GROUP="$2"; shift 2 ;;
    -h|--help)
      sed -n '4,17p' "$0" | sed 's/^# \?//'; exit 0 ;;
    -*)                   echo "Unknown flag: $1" >&2; exit 1 ;;
    *)
      if [[ -z "${ENV_NAME}" ]]; then ENV_NAME="$1"
      else echo "Unexpected positional arg: $1" >&2; exit 1
      fi
      shift ;;
  esac
done

USAGE="Usage: $0 <env-name> --subscription-id <guid> --tenant-id <guid> --client-id <guid> --dns-resource-group <name> [--email <addr>]"

if [[ -z "${ENV_NAME}" ]]; then
  echo "${USAGE}" >&2
  exit 1
fi

MISSING=()
[[ -z "${SUBSCRIPTION_ID}" ]]    && MISSING+=("--subscription-id")
[[ -z "${TENANT_ID}" ]]          && MISSING+=("--tenant-id")
[[ -z "${CLIENT_ID}" ]]          && MISSING+=("--client-id")
[[ -z "${DNS_RESOURCE_GROUP}" ]] && MISSING+=("--dns-resource-group")
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "ERROR: missing required flag(s): ${MISSING[*]}" >&2
  echo "${USAGE}" >&2
  exit 1
fi

EMAIL="${EMAIL:-devops+${ENV_NAME}@stack-ai.com}"
DOMAIN="${ENV_NAME}.${BASE_DOMAIN}"

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
echo "  Domain:     ${DOMAIN}"
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
sed_inplace -e "s/CUSTOMER_TENANT_ID/${TENANT_ID}/" "${ENV_DIR}/env.yaml"
sed_inplace -e "s/CUSTOMER_SUBSCRIPTION_ID/${SUBSCRIPTION_ID}/" "${ENV_DIR}/env.yaml"
sed_inplace -e "s/ATLANTIS_APP_CLIENT_ID/${CLIENT_ID}/" "${ENV_DIR}/env.yaml"
sed_inplace -e "s|<dns-rg>|${DNS_RESOURCE_GROUP}|" "${ENV_DIR}/env.yaml"
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

MANIFEST_SED=(
  -e "s/__ENV_NAME__/${ENV_NAME}/g"
  -e "s/__PLATFORM__/${PLATFORM}/g"
  -e "s|__EMAIL__|${EMAIL}|g"
  -e "s|__NOTIFY_EMAIL__|${EMAIL}|g"
  -e "s/__DOMAIN__/${DOMAIN}/g"
  -e "s/__SUBSCRIPTION_ID__/${SUBSCRIPTION_ID}/g"
  -e "s/__TENANT_ID__/${TENANT_ID}/g"
  -e "s/__DNS_RESOURCE_GROUP__/${DNS_RESOURCE_GROUP}/g"
)

find "${ENV_DIR}/manifests" -type f \( -name "*.yaml" -o -name "*.yml" \) -print0 | xargs -0 "${SED_INPLACE[@]}" "${MANIFEST_SED[@]}"

MANIFEST_COUNT=$(find "${ENV_DIR}/manifests" -type f \( -name "*.yaml" -o -name "*.yml" \) | wc -l | tr -d ' ')
echo "✓ Generated ${MANIFEST_COUNT} manifest files at environments/azure/${ENV_NAME}/manifests/"

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
echo "  1. Add dns_zone_id to environments/azure/${ENV_NAME}/env.yaml once the DNS zone exists."
echo ""
echo "  2. Add env-specific secrets to environments/azure/${ENV_NAME}/secrets.yaml:"
echo "       sops -d -i ...; edit customer.* + infra.acr; sops -e -i ..."
echo ""
echo "  3. Ensure RG + storage account '${ENV_NAME}stackaitfstate' exist."
echo ""
echo "  4. Open a PR (Atlantis runs terragrunt stack plan/apply)."
echo ""
