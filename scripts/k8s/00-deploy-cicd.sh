#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
NAMESPACE=${NAMESPACE:-cicd}
KEYVAULT_SYNC_REQUIRED=${KEYVAULT_SYNC_REQUIRED:-false}
BUILDKIT_DEPLOYMENT_NAME=${BUILDKIT_DEPLOYMENT_NAME:-buildkitd}
TRIVY_DEPLOYMENT_NAME=${TRIVY_DEPLOYMENT_NAME:-trivy}
KEYVAULT_SYNC_DEPLOYMENT_NAME=${KEYVAULT_SYNC_DEPLOYMENT_NAME:-keyvault-secret-sync}

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

kubectl -n "$NAMESPACE" rollout status "deploy/$BUILDKIT_DEPLOYMENT_NAME" --timeout=180s
kubectl -n "$NAMESPACE" rollout status "deploy/$TRIVY_DEPLOYMENT_NAME" --timeout=180s

if [ "$KEYVAULT_SYNC_REQUIRED" = "true" ]; then
  kubectl -n "$NAMESPACE" rollout status "deploy/$KEYVAULT_SYNC_DEPLOYMENT_NAME" --timeout=180s
else
  echo "INFO: skipping required rollout gate for $KEYVAULT_SYNC_DEPLOYMENT_NAME (KEYVAULT_SYNC_REQUIRED=false)." >&2
fi
