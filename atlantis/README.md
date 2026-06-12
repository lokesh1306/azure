# Hub Atlantis (Azure)

Azure-flavored Atlantis runner. Single commercial-Azure AKS hub drives all Azure spokes (commercial + Gov) via OIDC workload-identity federation. No bastion, no SSM tunnel — applies hit spoke ARM endpoints directly, kubectl/helm goes through `az aks command invoke`.

## One-time hub setup (manual, not in Terraform)

1. **AKS hub cluster** with workload identity + OIDC issuer enabled. Note the OIDC issuer URL — every spoke App Reg's federated credential trusts it.
2. **UAMI** `common-atlantis` in the hub resource group. Federated credential subject `system:serviceaccount:tools:atlantis`, issuer = the hub OIDC URL.
3. **Hub Key Vault** for hub-side secrets (Atlantis VCS token + sops key). Grant the UAMI `Key Vault Secrets User` for secrets and `Key Vault Crypto User` on the `sops` key.
4. **sops key**: create an RSA-2048 key named `sops` in the hub KV. Copy its versioned key URL into `azure/.sops.yaml`. This is a one-time op; the key is the only thing that decrypts every `environments/*/secrets.yaml`.
5. **GitHub App** for Atlantis VCS integration; store its private key in the hub KV as `atlantis-github-token`.

## What the customer creates (per spoke)

Driven by `azure/onboarding/customer-bootstrap.sh`:
- App Registration in the customer's Entra tenant
- Federated Identity Credential trusting the hub OIDC issuer URL + subject `system:serviceaccount:tools:atlantis`
- Subscription-scope role assignment (`Contributor` + `User Access Administrator`) for that App Reg
- State Storage Account + container `tfstate`
- Azure DNS public zone for `<env>.stack.ai`

The App Reg's `tenant_id`, `subscription_id`, `client_id`, and object ID go into `env.yaml`.

## Cross-cloud (Commercial → Gov)

The hub stays in commercial Azure. To deploy a Gov spoke:
- Customer creates the App Reg + FIC in the **Gov tenant** trusting the **commercial** hub OIDC issuer URL. Gov AAD fetches that URL's JWKS over public internet — no special config.
- Atlantis pod exchanges its SA token at the Gov AAD `login.microsoftonline.us` endpoint, gets a Gov-scoped access token, calls Gov ARM (`management.usgovcloudapi.net`). The unit's generated provider config sets `environment = "usgovernment"` from `env.yaml`.
- `az aks command invoke` against a Gov AKS cluster works the same as commercial — it's just an ARM call.

## Build & push the image

```sh
docker buildx build --platform linux/amd64,linux/arm64 \
  -t <hub-acr>.azurecr.io/common/atlantis:v1.0 \
  --push azure/atlantis/
```

Then update `app.yaml`'s `image.repository` and apply the Argo CD `Application`.
