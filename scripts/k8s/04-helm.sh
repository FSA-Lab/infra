#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
NAMESPACE=${NAMESPACE:-cicd}
CHART_PATH="$ROOT_DIR/config/helm/cicd-platform"
RELEASE_NAME=${RELEASE_NAME:-cicd-platform}
POSTGRESQL_RESOURCE_NAME=${POSTGRESQL_RESOURCE_NAME:-${RELEASE_NAME}-postgresql}
POSTGRESQL_SECRET_NAME=${POSTGRESQL_SECRET_NAME:-keycloak-postgresql}
VALUES_FILE=${VALUES_FILE:-}
AKS_RESOURCE_GROUP_NAME=${AKS_RESOURCE_GROUP_NAME:-}
EXTRA_VALUES_FILE=""
POSTGRESQL_PASSWORD=""
POSTGRESQL_ADMIN_PASSWORD=""

cleanup_orphaned_resource() {
  local kind=$1
  local name=$2
  local owner_release=""
  local owner_namespace=""

  if [ -z "$kind" ] || [ -z "$name" ]; then
    echo "ERROR: cleanup_orphaned_resource requires kind and name." >&2
    return 1
  fi

  if ! kubectl -n "$NAMESPACE" get "$kind" "$name" >/dev/null 2>&1; then
    return 0
  fi

  owner_release=$(kubectl -n "$NAMESPACE" get "$kind" "$name" -o jsonpath="{.metadata.annotations[\"meta.helm.sh/release-name\"]}" 2>/dev/null || true)
  owner_namespace=$(kubectl -n "$NAMESPACE" get "$kind" "$name" -o jsonpath="{.metadata.annotations[\"meta.helm.sh/release-namespace\"]}" 2>/dev/null || true)

  if [ -n "$owner_release" ]; then
    if [ "$owner_release" != "$RELEASE_NAME" ]; then
      echo "WARN: skipping cleanup for $kind/$name managed by Helm release $owner_release." >&2
      return 0
    fi
    if [ -n "$owner_namespace" ] && [ "$owner_namespace" != "$NAMESPACE" ]; then
      echo "WARN: skipping cleanup for $kind/$name managed by Helm release $owner_release in namespace $owner_namespace." >&2
      return 0
    fi
  fi

  kubectl -n "$NAMESPACE" delete "$kind" "$name" --ignore-not-found
}

decode_b64() {
  local label=${1:-value}
  local value=${2:-}
  local decoded=""

  if [ -z "$value" ]; then
    return 0
  fi

  if ! decoded=$(printf '%s' "$value" | base64 --decode 2>/dev/null); then
    echo "WARN: failed to decode base64 for $label from secret/$POSTGRESQL_SECRET_NAME in namespace $NAMESPACE." >&2
    return 0
  fi

  printf '%s' "$decoded"
}

get_secret_data_key() {
  local key=${1:-}
  local jsonpath=${2:-}
  local value=""

  if [ -z "$key" ] || [ -z "$jsonpath" ]; then
    echo "ERROR: get_secret_data_key requires key and jsonpath." >&2
    return 1
  fi

  if ! value=$(kubectl -n "$NAMESPACE" get secret "$POSTGRESQL_SECRET_NAME" -o jsonpath="$jsonpath" 2>/dev/null); then
    echo "WARN: failed to read key '$key' from secret/$POSTGRESQL_SECRET_NAME in namespace $NAMESPACE." >&2
    return 0
  fi

  printf '%s' "$value"
}

decode_secret_key() {
  local value=${1:-}
  local key=${2:-value}
  decode_b64 "$key" "$value"
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
  if ! cleanup_orphaned_resource service "$POSTGRESQL_RESOURCE_NAME"; then
    echo "ERROR: failed to cleanup orphaned service/$POSTGRESQL_RESOURCE_NAME." >&2
    exit 1
  fi
  if ! cleanup_orphaned_resource statefulset "$POSTGRESQL_RESOURCE_NAME"; then
    echo "ERROR: failed to cleanup orphaned statefulset/$POSTGRESQL_RESOURCE_NAME." >&2
    exit 1
  fi
fi

if kubectl -n "$NAMESPACE" get secret "$POSTGRESQL_SECRET_NAME" >/dev/null 2>&1; then
  POSTGRESQL_PASSWORD=$(decode_secret_key "$(get_secret_data_key "password" "{.data.password}")" "password")
  POSTGRESQL_ADMIN_PASSWORD=$(decode_secret_key "$(get_secret_data_key "postgres-password" "{.data['postgres-password']}")" "postgres-password")
fi

HELM_ARGS=(upgrade --install "$RELEASE_NAME" "$CHART_PATH" -n "$NAMESPACE" --create-namespace --wait --timeout 10m)

if [ -n "$VALUES_FILE" ]; then
  HELM_ARGS+=( -f "$VALUES_FILE" )
fi

if [ -n "$EXTRA_VALUES_FILE" ]; then
  HELM_ARGS+=( -f "$EXTRA_VALUES_FILE" )
fi

if [ -n "$POSTGRESQL_PASSWORD" ]; then
  HELM_ARGS+=( --set-string "global.postgresql.auth.password=$POSTGRESQL_PASSWORD" )
  HELM_ARGS+=( --set-string "keycloak.postgresql.auth.password=$POSTGRESQL_PASSWORD" )
fi

if [ -n "$POSTGRESQL_ADMIN_PASSWORD" ]; then
  HELM_ARGS+=( --set-string "global.postgresql.auth.postgresPassword=$POSTGRESQL_ADMIN_PASSWORD" )
  HELM_ARGS+=( --set-string "keycloak.postgresql.auth.postgresPassword=$POSTGRESQL_ADMIN_PASSWORD" )
fi

helm "${HELM_ARGS[@]}"
