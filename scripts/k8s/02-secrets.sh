#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
USE_FALLBACK_SECRETS=${USE_FALLBACK_SECRETS:-false}

kubectl apply -f "$ROOT_DIR/config/k8s/keyvault-secrets.yaml"

if [ "$USE_FALLBACK_SECRETS" = "true" ]; then
  kubectl apply -f "$ROOT_DIR/config/k8s/seeded-credentials-fallback.yaml"
fi
