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

## Required Secret Inputs

Update these placeholders before production deployment:

- `azure.workload.identity/client-id`
- Key Vault name and tenant in `keyvault-secrets.yaml`
- buildkit registry targets (`your-registry.azurecr.io`)
- all `REPLACE_WITH_STRONG_PASSWORD` tokens (fallback file)
- Keycloak client details in Jenkins OIDC JCasC (cicd realm)
- Key Vault secret `keycloak-postgresql-password` when using Key Vault sync
