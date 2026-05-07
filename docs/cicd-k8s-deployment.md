# AKS CI/CD Platform Deployment

This repository now includes Kubernetes manifests and a Helm umbrella chart for these required services:

- Jenkins
- BuildKit
- SonarQube
- Trivy
- Keycloak
- Ingress NGINX

## Directory Layout

- `/home/runner/work/infra/infra/config/k8s`
  - namespace, workload placement, Key Vault secret sync, seeded fallback secrets, BuildKit, Trivy
- `/home/runner/work/infra/infra/config/helm/cicd-platform`
  - Helm umbrella chart for Jenkins + SonarQube + Keycloak + ingress-nginx

## AKS-Specific Considerations Included

- Workload pinning to AKS `tools` node pool using `nodeSelector` + `tolerations`.
- Ingress NGINX configured with Azure Load Balancer health probe annotation.
- Azure Workload Identity hooks in the namespace/service account for Key Vault secret sync.

## Deploy

```bash
kubectl apply -f /home/runner/work/infra/infra/config/k8s/namespace.yaml
kubectl apply -f /home/runner/work/infra/infra/config/k8s/workload-placement.yaml
kubectl apply -f /home/runner/work/infra/infra/config/k8s/keyvault-secrets.yaml
# Fallback only if Key Vault sync is not available:
kubectl apply -f /home/runner/work/infra/infra/config/k8s/seeded-credentials-fallback.yaml
kubectl apply -f /home/runner/work/infra/infra/config/k8s/buildkit.yaml
kubectl apply -f /home/runner/work/infra/infra/config/k8s/trivy.yaml

helm dependency update /home/runner/work/infra/infra/config/helm/cicd-platform
helm upgrade --install cicd-platform /home/runner/work/infra/infra/config/helm/cicd-platform -n cicd --create-namespace
```

## Required Secret Inputs

Update these placeholders before production deployment:

- `azure.workload.identity/client-id`
- Key Vault name and tenant in `keyvault-secrets.yaml`
- buildkit registry targets (`replace.azurecr.io`)
- all `change-me-now` credentials
- Keycloak client details in Jenkins OIDC JCasC
