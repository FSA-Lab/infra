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
- `RELEASE_NAME` to override Helm release name (default `cicd-platform`)
- `POSTGRESQL_RESOURCE_NAME` to override orphan cleanup target for Keycloak PostgreSQL resources (default `${RELEASE_NAME}-postgresql`)
- `AKS_NAME` and `AKS_RESOURCE_GROUP_NAME` (or Terraform `TF_VAR_*`) to refresh kubeconfig from AKS before deploy
- `KEYVAULT_SYNC_REQUIRED=true` to fail deployment if keyvault-secret-sync does not become ready
- `STRICT_PLACEHOLDER_CHECK=true` to fail if Key Vault manifest placeholders are still present
- `BUILDKIT_DEPLOYMENT_NAME`, `TRIVY_DEPLOYMENT_NAME`, `KEYVAULT_SYNC_DEPLOYMENT_NAME` to override rollout target names
- `KEYVAULT_NAME` (or `AZURE_KEYVAULT_NAME`) so `04-helm.sh` can read/write persistent Keycloak PostgreSQL credentials
- `KEYCLOAK_POSTGRESQL_PASSWORD` and `KEYCLOAK_POSTGRESQL_ADMIN_PASSWORD` to provide persistent credentials from CI secret storage when cluster secret sync is unavailable
- `ORPHAN_CLEANUP_WAIT_SECONDS` to tune how long `04-helm.sh` waits for orphan PostgreSQL resources to fully delete (default `60`)
- `RECREATE_POSTGRESQL_STATEFULSET_ON_IMMUTABLE_ERROR` to allow one delete/recreate retry when Helm upgrade hits immutable StatefulSet spec changes for `${POSTGRESQL_RESOURCE_NAME}` (default `true`)

`04-helm.sh` also performs a preflight cleanup for orphaned Service and StatefulSet named by `POSTGRESQL_RESOURCE_NAME` (default `${RELEASE_NAME}-postgresql`) when Helm release metadata is missing, while skipping resources owned by a different Helm release. When cleanup occurs, the script now waits for deletion completion before proceeding to Helm install/upgrade.

When a Helm upgrade fails due to immutable spec updates on `statefulset/${POSTGRESQL_RESOURCE_NAME}`, `04-helm.sh` can delete and recreate the PostgreSQL StatefulSet (and matching Service) and retry Helm once.

`04-helm.sh` now enforces durable Keycloak PostgreSQL credentials before Helm upgrade:

- Reads existing values from `secret/keycloak-postgresql` when present.
- Falls back to `KEYCLOAK_POSTGRESQL_PASSWORD` and `KEYCLOAK_POSTGRESQL_ADMIN_PASSWORD`.
- Falls back to Azure Key Vault secrets when `KEYVAULT_NAME` (or `AZURE_KEYVAULT_NAME`) is set.
- Upserts `secret/keycloak-postgresql` before Helm upgrade.
- Attempts to persist missing Key Vault secrets from resolved values (best-effort).

## Key Vault Sync Prerequisite

`config/k8s/keyvault-secrets.yaml` requires the SecretProviderClass CRD from Secrets Store CSI Driver.

Behavior in `02-secrets.sh`:

- If CRD exists, Key Vault sync resources are applied.
- If CRD is missing and `KEYVAULT_SYNC_REQUIRED=true`, deployment fails fast.
- If CRD is missing and `KEYVAULT_SYNC_REQUIRED=false`, Key Vault sync apply is skipped with warning.
- Set `USE_FALLBACK_SECRETS=true` to continue with seeded fallback secrets when Key Vault sync is unavailable.

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
