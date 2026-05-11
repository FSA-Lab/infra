#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
NAMESPACE=${NAMESPACE:-cicd}

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
