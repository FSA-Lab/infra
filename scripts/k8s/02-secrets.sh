#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
USE_FALLBACK_SECRETS=${USE_FALLBACK_SECRETS:-false}

if grep -q "REPLACE-WITH-YOUR-" "$ROOT_DIR/config/k8s/keyvault-secrets.yaml"; then
  echo "WARN: keyvault-secrets.yaml still has placeholder workload identity values. Update before production." >&2
fi

kubectl apply -f "$ROOT_DIR/config/k8s/keyvault-secrets.yaml"

if [ "$USE_FALLBACK_SECRETS" = "true" ]; then
  kubectl apply -f "$ROOT_DIR/config/k8s/seeded-credentials-fallback.yaml"
fi
