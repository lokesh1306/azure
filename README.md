# Azure Spoke Infrastructure

Mirror of `infrastructure/` for Azure spokes (commercial + Azure Government). One commercial-Azure hub Atlantis drives many customer spokes; each spoke is a separate Entra tenant + subscription, regardless of cloud.

## Layout

```
azure/
├── root.hcl                    Terragrunt remote_state (azurerm backend, OIDC auth)
├── constants.hcl               Hub OIDC issuer, per-cloud endpoint suffixes
├── modules/                    Terraform modules (Azure equivalents of infrastructure/modules)
│   ├── bootstrap-secrets/      Resource Group + Key Vault + secret material  (spoke)
│   ├── infrastructure/         Wrapper: platform                              (spoke + hub)
│   ├── platform/               VNet, NAT, NSGs, AKS (private, workload identity), Log Analytics
│   ├── spoke-apps/             Wrapper: addons + stackai-apps + spoke-bootstrap (spoke)
│   ├── addons/                 UAMIs + FICs for external-secrets, external-dns, cert-manager
│   ├── stackai-apps/           Storage Accounts, KV secrets, UAMIs for app workloads
│   ├── spoke-bootstrap/        SPIRE node-attestor UAMI                       (spoke)
│   └── argocd/                 Argo CD helm release + bootstrap ApplicationSet (hub + spoke)
├── units/external/             Terragrunt units (06-secrets, 07-infrastructure, 08-apps)
├── templates/external/         env.yaml + terragrunt.stack.hcl skeleton
├── environments/
│   ├── byoc/                   Per-spoke env directories
│   └── common/                 Hub environment (plain terraform, mirrors infra/environments/common/)
│       └── terraform/          AKS hub + Argo CD hub
├── atlantis/                   Hub Atlantis Dockerfile + Argo CD Application
└── onboarding/                 Customer-side prereq bootstrap script + docs
```

## Hub bootstrap (one-time, manual)

The hub lives under `environments/common/terraform/` — plain Terraform, run from a developer workstation with `az login` to the hub commercial-Azure subscription. Mirrors `infrastructure/environments/common/terraform/`.

Prereqs (you create these by hand, once):
- State Storage Account + `tfstate` container for the hub backend
- Public Azure DNS zone for the hub domain (e.g. `ops.stack.ai`)
- User-Assigned Managed Identity `common-atlantis` (no federated credential yet — that gets added after the cluster exists)
- Key Vault holding the ArgoCD SSO secret (`common-argocd-secrets` JSON: `{oauth_client_id, oauth_client_secret}`), the Atlantis VCS secrets, and an RSA `sops` key (the one `.sops.yaml` points at)

Apply order:
1. `cd azure/environments/common/terraform && terraform init -backend-config=...`
2. Fill in `terraform.tfvars` (all `REPLACE_WITH_*` placeholders)
3. `terraform apply` — creates the hub RG, VNet, AKS, Log Analytics, and installs Argo CD via Helm
4. Grab `terraform output cluster_oidc_issuer_url` — use that as the `issuer` in every spoke App Registration's federated identity credential, and add a federated credential to the hub `common-atlantis` UAMI with the same issuer + subject `system:serviceaccount:tools:atlantis`
5. Apply the Atlantis Argo CD `Application` from `azure/atlantis/`

Note: the hub AKS API is private, so terraform's helm/kubernetes/kubectl providers (and your kubectl) need network reachability to the private FQDN — VPN, Azure Bastion to a jumpbox in the VNet, or run terraform from a self-hosted runner in the VNet.

## Mental model

| AWS today | Azure equivalent |
|---|---|
| `terraform_role_arn` (IAM role + trust policy + Admin) | App Registration in customer tenant + Federated Identity Credential trusting hub AKS OIDC issuer + Contributor at subscription scope |
| State bucket `<env>-stackai-terraform-state` | Storage Account `<env>stackaitfstate` + container `tfstate` (blob lease lock) |
| Route 53 public zone | Azure DNS public zone (customer-created, customer-delegated) |

The three manual prereqs per spoke live in `onboarding/customer-bootstrap.sh`. Atlantis then applies `06-secrets` → `07-infrastructure` → `08-apps` against the spoke subscription via OIDC federation; Argo CD on the spoke AKS takes over for manifests.

## Cloud environments

`env.yaml` carries `cloud_environment: commercial` or `cloud_environment: usgovernment`. The unit terragrunt config maps `commercial → public` when emitting the `azurerm` provider's `environment` field (the provider itself only accepts `public`/`usgovernment`/`china`/`german`); per-cloud endpoint suffixes (private DNS zone names, ARM, AAD) come from `constants.hcl`. Lighthouse is **not** used — federation is direct OIDC, which works cross-cloud because Gov AAD trusts your public hub OIDC issuer URL natively.
