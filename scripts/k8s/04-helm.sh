#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
NAMESPACE=${NAMESPACE:-cicd}
CHART_PATH="$ROOT_DIR/config/helm/cicd-platform"
RELEASE_NAME=${RELEASE_NAME:-cicd-platform}
POSTGRESQL_RESOURCE_NAME=${POSTGRESQL_RESOURCE_NAME:-${RELEASE_NAME}-postgresql}
VALUES_FILE=${VALUES_FILE:-}
AKS_RESOURCE_GROUP_NAME=${AKS_RESOURCE_GROUP_NAME:-}
EXTRA_VALUES_FILE=""

cleanup_orphaned_resource() {
  local kind=$1
  local name=$2
  local owner_release=""
  local owner_namespace=""

  if ! kubectl -n "$NAMESPACE" get "$kind" "$name" >/dev/null 2>&1; then
    return 0
  fi

  owner_release=$(kubectl -n "$NAMESPACE" get "$kind" "$name" -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' 2>/dev/null || true)
  owner_namespace=$(kubectl -n "$NAMESPACE" get "$kind" "$name" -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' 2>/dev/null || true)

  if [ -n "$owner_release" ]; then
    if [ "$owner_release" = "$RELEASE_NAME" ] && { [ -z "$owner_namespace" ] || [ "$owner_namespace" = "$NAMESPACE" ]; }; then
      :
    else
      echo "WARN: skipping cleanup for $kind/$name managed by Helm release $owner_release in namespace $owner_namespace." >&2
      return 0
    fi
  fi

  kubectl -n "$NAMESPACE" delete "$kind" "$name" --ignore-not-found
}

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
  cleanup_orphaned_resource service "$POSTGRESQL_RESOURCE_NAME"
  cleanup_orphaned_resource statefulset "$POSTGRESQL_RESOURCE_NAME"
fi

HELM_ARGS=(upgrade --install "$RELEASE_NAME" "$CHART_PATH" -n "$NAMESPACE" --create-namespace --wait --timeout 10m)

if [ -n "$VALUES_FILE" ]; then
  HELM_ARGS+=( -f "$VALUES_FILE" )
fi

if [ -n "$EXTRA_VALUES_FILE" ]; then
  HELM_ARGS+=( -f "$EXTRA_VALUES_FILE" )
fi

helm "${HELM_ARGS[@]}"
