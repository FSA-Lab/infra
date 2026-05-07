#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
NAMESPACE=${NAMESPACE:-cicd}
KEYVAULT_SYNC_REQUIRED=${KEYVAULT_SYNC_REQUIRED:-false}

# Prefer AKS values exported by Terraform workflow, fallback to plain names.
AKS_NAME=${AKS_NAME:-${TF_VAR_AKS_NAME:-}}
AKS_RESOURCE_GROUP_NAME=${AKS_RESOURCE_GROUP_NAME:-${TF_VAR_AKS_RESOURCE_GROUP_NAME:-}}

if command -v az >/dev/null 2>&1 && [ -n "$AKS_NAME" ] && [ -n "$AKS_RESOURCE_GROUP_NAME" ]; then
  az aks get-credentials --resource-group "$AKS_RESOURCE_GROUP_NAME" --name "$AKS_NAME" --overwrite-existing
fi

bash "$ROOT_DIR/scripts/k8s/01-namespace.sh"
bash "$ROOT_DIR/scripts/k8s/02-secrets.sh"
bash "$ROOT_DIR/scripts/k8s/03-tools.sh"
export AKS_RESOURCE_GROUP_NAME
bash "$ROOT_DIR/scripts/k8s/04-helm.sh"

kubectl -n "$NAMESPACE" rollout status deploy/buildkitd --timeout=180s
kubectl -n "$NAMESPACE" rollout status deploy/trivy --timeout=180s
if ! kubectl -n "$NAMESPACE" rollout status deploy/keyvault-secret-sync --timeout=180s; then
  if [ "$KEYVAULT_SYNC_REQUIRED" = "true" ]; then
    echo "ERROR: keyvault-secret-sync rollout failed and KEYVAULT_SYNC_REQUIRED=true." >&2
    exit 1
  fi
  echo "WARN: keyvault-secret-sync rollout did not complete. Check SecretProviderClass and AKS workload identity settings." >&2
fi
