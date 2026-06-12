# Customer onboarding (Azure spoke)

What the customer runs **once** in their own tenant + subscription to be ready for Atlantis-driven deploys. Mirrors the manual prereqs from AWS (trust role + state bucket + DNS zone), plus a spoke resource group (Azure-only — there's no implicit container like an AWS account-wide namespace):

| AWS prereq | Azure equivalent |
|---|---|
| IAM role `StackAIRole` + trust policy + Admin | App Registration + Federated Identity Credential (trusts hub OIDC) + `Contributor`, `User Access Administrator`, and `Key Vault Administrator` at subscription scope (KV data-plane is separate from ARM control-plane under RBAC mode) |
| — | **Spoke Resource Group** `stackai-<env>-rg` (every Azure resource needs an RG; we don't create it in Terraform so customers can place it under their own naming/policy constraints) |
| S3 bucket `<env>-stackai-terraform-state` | Resource Group `<env>-tfstate-rg` + Storage Account `<env>stackaitfstate` + container `tfstate` |
| Route 53 public zone | Azure DNS public zone for `<env>.stack.ai` |

## Prerequisites

- `az` CLI installed and logged into the customer's tenant (`az login --tenant <id>`)
- `jq`
- Permissions in the customer tenant: `Application Administrator` (to create the App Reg) and `Owner` or `User Access Administrator` on the target subscription (to grant role assignments)
- The **hub OIDC issuer URL** from the commercial-Azure Atlantis AKS cluster — Stack AI provides this

## Run

```sh
ENV_NAME=env58 \
HUB_OIDC_ISSUER='https://commercial-hub.oic.azurecontainer.io/<guid>/' \
CLOUD_ENVIRONMENT=commercial \
LOCATION=eastus \
DOMAIN=env58.stack.ai \
./customer-bootstrap.sh
```

For Azure Government, set `CLOUD_ENVIRONMENT=usgovernment` and `LOCATION=usgovvirginia` (or another Gov region). The script does `az cloud set` to swap to Gov ARM endpoints. The federation still trusts the **commercial** hub OIDC issuer URL — that's the point: one hub, both clouds.

## After running

The script prints the five values to paste into `env.yaml`:

- `tenant_id`
- `subscription_id`
- `client_id`
- `atlantis_principal_id`
- `resource_group_name`
- `dns_zone_id`

Then delegate the zone's NS records from the parent DNS zone (typically held by Stack AI for `*.stack.ai`).

## Re-runs / rotation

Re-running the script is **not** idempotent on App Reg creation — it will create a duplicate. To rotate or re-bind, edit the App Reg directly via Portal/CLI rather than re-running. The state SA and DNS zone are skipped if they already exist.
