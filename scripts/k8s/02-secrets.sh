#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
USE_FALLBACK_SECRETS=${USE_FALLBACK_SECRETS:-false}
STRICT_PLACEHOLDER_CHECK=${STRICT_PLACEHOLDER_CHECK:-false}
KEYVAULT_SYNC_REQUIRED=${KEYVAULT_SYNC_REQUIRED:-false}

if grep -q "REPLACE-WITH-YOUR-" "$ROOT_DIR/config/k8s/keyvault-secrets.yaml"; then
  if [ "$STRICT_PLACEHOLDER_CHECK" = "true" ]; then
    echo "ERROR: keyvault-secrets.yaml has placeholder workload identity values and STRICT_PLACEHOLDER_CHECK=true." >&2
    exit 1
  fi
  echo "WARN: keyvault-secrets.yaml still has placeholder workload identity values. Update before production." >&2
fi

if kubectl get crd secretproviderclasses.secrets-store.csi.x-k8s.io >/dev/null 2>&1; then
  kubectl apply -f "$ROOT_DIR/config/k8s/keyvault-secrets.yaml"
else
  if [ "$KEYVAULT_SYNC_REQUIRED" = "true" ]; then
    echo "ERROR: secretproviderclasses.secrets-store.csi.x-k8s.io CRD is missing and KEYVAULT_SYNC_REQUIRED=true." >&2
    echo "Install Secrets Store CSI Driver + Azure provider before deploying Key Vault sync resources." >&2
    exit 1
  fi
  echo "WARN: SecretProviderClass CRD is missing. Skipping keyvault-secrets.yaml apply." >&2
  echo "Install Secrets Store CSI Driver + Azure provider, or continue with USE_FALLBACK_SECRETS=true." >&2
fi

if [ "$USE_FALLBACK_SECRETS" = "true" ]; then
  kubectl apply -f "$ROOT_DIR/config/k8s/seeded-credentials-fallback.yaml"
fi
