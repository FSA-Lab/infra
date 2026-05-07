#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
NAMESPACE=${NAMESPACE:-cicd}
CHART_PATH="$ROOT_DIR/config/helm/cicd-platform"
RELEASE_NAME=${RELEASE_NAME:-cicd-platform}
VALUES_FILE=${VALUES_FILE:-}
AKS_RESOURCE_GROUP_NAME=${AKS_RESOURCE_GROUP_NAME:-}
EXTRA_VALUES_FILE=""

helm dependency update "$CHART_PATH"

if [ -n "$AKS_RESOURCE_GROUP_NAME" ]; then
  umask 077
  TMP_BASE="${TMPDIR:-/tmp}"
  EXTRA_VALUES_FILE=$(mktemp "${TMP_BASE}/helm-values.XXXXXXXXXX.yaml")
  trap 'rm -f "$EXTRA_VALUES_FILE"' EXIT
  cat > "$EXTRA_VALUES_FILE" <<YAML
ingress-nginx:
  controller:
    service:
      annotations:
        service.beta.kubernetes.io/azure-load-balancer-resource-group: "$AKS_RESOURCE_GROUP_NAME"
YAML
fi

if ! helm status "$RELEASE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  kubectl -n "$NAMESPACE" delete service "${RELEASE_NAME}-postgresql" --ignore-not-found
  kubectl -n "$NAMESPACE" delete statefulset "${RELEASE_NAME}-postgresql" --ignore-not-found
fi

HELM_ARGS=(upgrade --install "$RELEASE_NAME" "$CHART_PATH" -n "$NAMESPACE" --create-namespace --wait --timeout 10m)

if [ -n "$VALUES_FILE" ]; then
  HELM_ARGS+=( -f "$VALUES_FILE" )
fi

if [ -n "$EXTRA_VALUES_FILE" ]; then
  HELM_ARGS+=( -f "$EXTRA_VALUES_FILE" )
fi

helm "${HELM_ARGS[@]}"
