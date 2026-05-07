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

## Deploy

```bash
kubectl apply -f config/k8s/namespace.yaml
kubectl apply -f config/k8s/workload-placement.yaml
kubectl apply -f config/k8s/keyvault-secrets.yaml
# Fallback only if Key Vault sync is not available:
kubectl apply -f config/k8s/seeded-credentials-fallback.yaml
kubectl apply -f config/k8s/buildkit.yaml
kubectl apply -f config/k8s/trivy.yaml

helm dependency update config/helm/cicd-platform
helm upgrade --install cicd-platform config/helm/cicd-platform -n cicd --create-namespace
```

## Required Secret Inputs

Update these placeholders before production deployment:

- `azure.workload.identity/client-id`
- Key Vault name and tenant in `keyvault-secrets.yaml`
- buildkit registry targets (`your-registry.azurecr.io`)
- all `change-me-now` credentials
- all `REPLACE_WITH_STRONG_PASSWORD` tokens (fallback file)
- Keycloak client details in Jenkins OIDC JCasC (cicd realm)
- Key Vault secret `keycloak-postgresql-password` when using Key Vault sync
