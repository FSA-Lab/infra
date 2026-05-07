# AKS CI/CD Platform Deployment

This repository now includes Kubernetes manifests and a Helm umbrella chart for these required services:

- Jenkins
- BuildKit
- SonarQube
- Trivy
- Keycloak
- Ingress NGINX

## Directory Layout

- `config/k8s`
  - namespace, workload placement, Key Vault secret sync, seeded fallback secrets, BuildKit, Trivy
- `config/helm/cicd-platform`
  - Helm umbrella chart for Jenkins + SonarQube + Keycloak + ingress-nginx

## AKS-Specific Considerations Included

- Workload pinning to AKS `tools` node pool using `nodeSelector` + `tolerations`.
- Ingress NGINX configured with Azure Load Balancer health probe annotation.
- Azure Workload Identity hooks in the namespace/service account for Key Vault secret sync.
- Deployment scripts are compatible with Terraform workflow variables:
  - `TF_VAR_AKS_NAME`
  - `TF_VAR_AKS_RESOURCE_GROUP_NAME`

## Deployment Order

The deployment order follows repository infra dependencies and is encoded in `/scripts/k8s`:

1. `01-namespace.sh` → namespace and service accounts
2. `02-secrets.sh` → Key Vault sync (and optional seeded fallback)
3. `03-tools.sh` → BuildKit and Trivy manifests
4. `04-helm.sh` → Helm dependencies + chart install/upgrade (Jenkins, SonarQube, Keycloak, ingress)

Use the orchestrator script:

```bash
./scripts/k8s/00-deploy-cicd.sh
```

Or continue using:

```bash
./scripts/helm.sh
```

Optional flags:

- `USE_FALLBACK_SECRETS=true` to apply seeded fallback secrets
- `VALUES_FILE=/path/to/override-values.yaml` for chart overrides
- `AKS_NAME` and `AKS_RESOURCE_GROUP_NAME` (or Terraform `TF_VAR_*`) to refresh kubeconfig from AKS before deploy
- `KEYVAULT_SYNC_REQUIRED=true` to fail deployment if keyvault-secret-sync does not become ready
- `STRICT_PLACEHOLDER_CHECK=true` to fail if Key Vault manifest placeholders are still present
- `BUILDKIT_DEPLOYMENT_NAME`, `TRIVY_DEPLOYMENT_NAME`, `KEYVAULT_SYNC_DEPLOYMENT_NAME` to override rollout target names

## Required Secret Inputs

Update all placeholder patterns before production deployment:

- `REPLACE-WITH-YOUR-CLIENT-ID`
- `REPLACE-WITH-YOUR-TENANT-ID`
- `replace-with-keyvault-name`
- `your-registry.azurecr.io`
- `REPLACE_WITH_STRONG_PASSWORD`
- `REPLACE_WITH_KEYCLOAK_CLIENT_ID`
- `REPLACE_WITH_KEYCLOAK_CLIENT_SECRET`
- `REPLACE_BASE64_AUTH_HERE`
