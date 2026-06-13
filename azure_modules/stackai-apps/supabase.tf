locals {
  supabase_identifier = "${var.environment}-supabase"
}

resource "azurerm_storage_account" "supabase_storage" {
  count = var.enable_supabase && var.supabase_use_s3_storage ? 1 : 0

  name                            = substr("${local.storage_name_base}supabase", 0, 24)
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "supabase_storage" {
  count = var.enable_supabase && var.supabase_use_s3_storage ? 1 : 0

  name                  = "supabase"
  storage_account_id    = azurerm_storage_account.supabase_storage[0].id
  container_access_type = "private"
}

resource "azurerm_user_assigned_identity" "supabase_storage" {
  count = var.enable_supabase && var.supabase_use_s3_storage ? 1 : 0

  name                = "${var.environment}-supabase-storage"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_federated_identity_credential" "supabase_storage" {
  count = var.enable_supabase && var.supabase_use_s3_storage ? 1 : 0

  name                      = "${var.environment}-supabase-storage"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.cluster_oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.supabase_storage[0].id
  subject                   = "system:serviceaccount:supabase:supabase-storage"
}

resource "azurerm_role_assignment" "supabase_storage" {
  count = var.enable_supabase && var.supabase_use_s3_storage ? 1 : 0

  scope                = azurerm_storage_account.supabase_storage[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.supabase_storage[0].principal_id
}

resource "random_password" "supabase_db" {
  count   = var.enable_supabase ? 1 : 0
  length  = 32
  special = false

  keepers = {
    seed = "${local.supabase_identifier}-db-password-v1"
  }
}

resource "random_password" "supabase_jwt_secret" {
  count   = var.enable_supabase ? 1 : 0
  length  = 64
  special = false

  keepers = {
    seed = "${local.supabase_identifier}-jwt-secret-v1"
  }
}

resource "random_password" "supabase_dashboard" {
  count   = var.enable_supabase ? 1 : 0
  length  = 32
  special = false

  keepers = {
    seed = "${local.supabase_identifier}-dashboard-v1"
  }
}

resource "random_password" "supabase_logflare" {
  count   = var.enable_supabase ? 1 : 0
  length  = 32
  special = false

  keepers = {
    seed = "${local.supabase_identifier}-logflare-v1"
  }
}

resource "random_password" "supabase_realtime_secret" {
  count   = var.enable_supabase ? 1 : 0
  length  = 64
  special = false

  keepers = {
    seed = "${local.supabase_identifier}-realtime-v1"
  }
}

resource "random_password" "supabase_meta_crypto" {
  count   = var.enable_supabase ? 1 : 0
  length  = 32
  special = false

  keepers = {
    seed = "${local.supabase_identifier}-meta-crypto-v1"
  }
}

resource "random_password" "supabase_admin_user" {
  count   = var.enable_supabase ? 1 : 0
  length  = 32
  special = false

  keepers = {
    seed = "${local.supabase_identifier}-admin-user-v1"
  }
}

resource "random_password" "supabase_minio" {
  count   = var.enable_supabase ? 1 : 0
  length  = 32
  special = false

  keepers = {
    seed = "${local.supabase_identifier}-minio-v1"
  }
}

# Fernet encryption key (32 url-safe base64 bytes) derived deterministically from the JWT secret.
data "external" "supabase_encryption_key" {
  count = var.enable_supabase ? 1 : 0

  program = ["bash", "-c", <<-EOT
    python3 << 'EOF'
import json, hashlib, base64
jwt_secret = "${random_password.supabase_jwt_secret[0].result}"
hash_bytes = hashlib.sha256(jwt_secret.encode()).digest()
print(json.dumps({"key": base64.urlsafe_b64encode(hash_bytes).decode()}))
EOF
  EOT
  ]

  depends_on = [random_password.supabase_jwt_secret]
}

# Deterministic anon / service_role JWTs signed with the JWT secret (HS256).
data "external" "supabase_jwt_tokens" {
  count = var.enable_supabase ? 1 : 0

  program = ["bash", "-c", <<-EOT
    python3 << 'EOF'
import json, base64, hmac, hashlib
jwt_secret = "${random_password.supabase_jwt_secret[0].result}"

def b64url(data):
    return base64.b64encode(data).decode("utf-8").rstrip("=").replace("+", "-").replace("/", "_")

def jwt(payload, secret):
    header = {"alg": "HS256", "typ": "JWT"}
    msg = b64url(json.dumps(header).encode()) + "." + b64url(json.dumps(payload).encode())
    sig = hmac.new(secret.encode(), msg.encode(), hashlib.sha256).digest()
    return msg + "." + b64url(sig)

exp, iat = 2000000000, 1600000000
anon = {"aud": "authenticated", "exp": exp, "iat": iat, "iss": "supabase", "role": "anon", "sub": "00000000-0000-0000-0000-000000000000"}
svc = {"aud": "authenticated", "exp": exp, "iat": iat, "iss": "supabase", "role": "service_role", "sub": "00000000-0000-0000-0000-000000000001"}
print(json.dumps({"anon_key": jwt(anon, jwt_secret), "service_key": jwt(svc, jwt_secret)}))
EOF
  EOT
  ]

  depends_on = [random_password.supabase_jwt_secret]
}

resource "tls_private_key" "supabase_saml" {
  count = var.enable_supabase && var.supabase_enable_saml ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 2048
}

# PEM -> PKCS#1 DER base64 (required by GoTrue SAML).
data "external" "supabase_saml_key" {
  count = var.enable_supabase && var.supabase_enable_saml ? 1 : 0

  program = ["bash", "-c", <<-EOT
    set -e
    cat <<'PEMKEY' | openssl rsa -traditional -outform DER 2>/dev/null | base64 | tr -d '\n' | jq -R '{"key": .}'
${tls_private_key.supabase_saml[0].private_key_pem}
PEMKEY
  EOT
  ]

  depends_on = [tls_private_key.supabase_saml]
}

resource "azurerm_key_vault_secret" "supabase_db_password" {
  count = var.enable_supabase ? 1 : 0

  name         = "${local.supabase_identifier}-db-password"
  key_vault_id = var.key_vault_id
  value        = random_password.supabase_db[0].result

  lifecycle {
    ignore_changes = [value]
  }
}

resource "azurerm_key_vault_secret" "supabase_secrets" {
  count = var.enable_supabase ? 1 : 0

  name         = "${local.supabase_identifier}-secrets"
  key_vault_id = var.key_vault_id
  value = jsonencode({
    db_password              = random_password.supabase_db[0].result
    jwt_secret               = random_password.supabase_jwt_secret[0].result
    anon_key                 = data.external.supabase_jwt_tokens[0].result["anon_key"]
    service_role_key         = data.external.supabase_jwt_tokens[0].result["service_key"]
    username                 = "admin"
    dashboard_password       = random_password.supabase_dashboard[0].result
    openAiApiKey             = ""
    logflare_api_key         = random_password.supabase_logflare[0].result
    realtime_secret_key_base = random_password.supabase_realtime_secret[0].result
    meta_crypto_key          = random_password.supabase_meta_crypto[0].result
    encryption_key           = data.external.supabase_encryption_key[0].result["key"]
    smtp_username            = "placeholder"
    smtp_password            = "placeholder"
    saml_private_key         = var.supabase_enable_saml ? data.external.supabase_saml_key[0].result["key"] : ""
    admin_email              = var.admin_email
    admin_password           = random_password.supabase_admin_user[0].result
    org_id                   = "${var.environment}-org"
    org_name                 = var.org_name
    minio_secret_key         = random_password.supabase_minio[0].result
  })

  lifecycle {
    ignore_changes = [value]
  }
}
