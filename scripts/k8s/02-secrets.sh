#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
USE_FALLBACK_SECRETS=${USE_FALLBACK_SECRETS:-false}
STRICT_PLACEHOLDER_CHECK=${STRICT_PLACEHOLDER_CHECK:-false}

if grep -q "REPLACE-WITH-YOUR-" "$ROOT_DIR/config/k8s/keyvault-secrets.yaml"; then
  if [ "$STRICT_PLACEHOLDER_CHECK" = "true" ]; then
    echo "ERROR: keyvault-secrets.yaml has placeholder workload identity values and STRICT_PLACEHOLDER_CHECK=true." >&2
    exit 1
  fi
  echo "WARN: keyvault-secrets.yaml still has placeholder workload identity values. Update before production." >&2
fi

kubectl apply -f "$ROOT_DIR/config/k8s/keyvault-secrets.yaml"

if [ "$USE_FALLBACK_SECRETS" = "true" ]; then
  kubectl apply -f "$ROOT_DIR/config/k8s/seeded-credentials-fallback.yaml"
fi
