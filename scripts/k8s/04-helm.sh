#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
NAMESPACE=${NAMESPACE:-cicd}
CHART_PATH="$ROOT_DIR/config/helm/cicd-platform"
RELEASE_NAME=${RELEASE_NAME:-cicd-platform}
POSTGRESQL_RESOURCE_NAME=${POSTGRESQL_RESOURCE_NAME:-${RELEASE_NAME}-postgresql}
# Matches cicd-platform values: keycloak.postgresql.auth.existingSecret
POSTGRESQL_SECRET_NAME=${POSTGRESQL_SECRET_NAME:-keycloak-postgresql}
VALUES_FILE=${VALUES_FILE:-}
AKS_RESOURCE_GROUP_NAME=${AKS_RESOURCE_GROUP_NAME:-}
TMP_BASE=${TMPDIR:-/tmp}
EXTRA_VALUES_FILE=""
POSTGRESQL_PASSWORD=""
POSTGRESQL_ADMIN_PASSWORD=""
POSTGRESQL_PASSWORD_FILE=""
POSTGRESQL_ADMIN_PASSWORD_FILE=""

cleanup_temp_files() {
  if [ -n "$EXTRA_VALUES_FILE" ] && [ -f "$EXTRA_VALUES_FILE" ]; then
    rm -f "$EXTRA_VALUES_FILE"
  fi
  if [ -n "$POSTGRESQL_PASSWORD_FILE" ] && [ -f "$POSTGRESQL_PASSWORD_FILE" ]; then
    rm -f "$POSTGRESQL_PASSWORD_FILE"
  fi
  if [ -n "$POSTGRESQL_ADMIN_PASSWORD_FILE" ] && [ -f "$POSTGRESQL_ADMIN_PASSWORD_FILE" ]; then
    rm -f "$POSTGRESQL_ADMIN_PASSWORD_FILE"
  fi
}
trap cleanup_temp_files EXIT

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

decode_base64() {
  local label=${1:-value}
  local value=${2:-}
  local decoded=""

  if [ -z "$value" ]; then
    return 0
  fi

  if ! decoded=$(printf '%s' "$value" | base64 --decode 2>/dev/null); then
    decoded=""
    echo "WARN: failed to decode base64 for key '$label' (value may be invalid base64); continuing with empty decoded value." >&2
    return 0
  fi

  printf '%s' "$decoded"
}

get_secret_data_key() {
  local key_label=${1:-}
  local jsonpath_query=""
  local value=""

  if [ -z "$key_label" ]; then
    echo "ERROR: get_secret_data_key requires key label." >&2
    return 1
  fi

  jsonpath_query="{.data['$key_label']}"

  if ! value=$(kubectl -n "$NAMESPACE" get secret "$POSTGRESQL_SECRET_NAME" -o jsonpath="$jsonpath_query" 2>/dev/null); then
    value=""
    echo "WARN: key '$key_label' is missing or unreadable in secret/$POSTGRESQL_SECRET_NAME; continuing with empty value." >&2
    return 0
  fi

  printf '%s' "$value"
}

ensure_extra_values_file() {
  if [ -n "$EXTRA_VALUES_FILE" ]; then
    return 0
  fi

  umask 077
  EXTRA_VALUES_FILE=$(mktemp "${TMP_BASE}/helm-values.XXXXXXXXXX.yaml")
}

create_secret_value_file() {
  local value=${1:-}
  local file_path=""

  umask 077
  file_path=$(mktemp "${TMP_BASE}/helm-secret.XXXXXXXXXX")
  if ! printf '%s' "$value" > "$file_path"; then
    rm -f "$file_path"
    return 1
  fi
  printf '%s' "$file_path"
}

helm dependency update "$CHART_PATH"

if [ -n "$AKS_RESOURCE_GROUP_NAME" ]; then
  ensure_extra_values_file
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
  secret_password_b64=$(get_secret_data_key "password")
  secret_postgres_password_b64=$(get_secret_data_key "postgres-password")

  POSTGRESQL_PASSWORD=$(decode_base64 "password" "$secret_password_b64")
  POSTGRESQL_ADMIN_PASSWORD=$(decode_base64 "postgres-password" "$secret_postgres_password_b64")
fi

if [ -n "$POSTGRESQL_PASSWORD" ] || [ -n "$POSTGRESQL_ADMIN_PASSWORD" ]; then
  if [ -n "$POSTGRESQL_PASSWORD" ]; then
    if ! POSTGRESQL_PASSWORD_FILE=$(create_secret_value_file "$POSTGRESQL_PASSWORD"); then
      echo "ERROR: failed to create temporary file for PostgreSQL user password." >&2
      exit 1
    fi
  fi
  if [ -n "$POSTGRESQL_ADMIN_PASSWORD" ]; then
    if ! POSTGRESQL_ADMIN_PASSWORD_FILE=$(create_secret_value_file "$POSTGRESQL_ADMIN_PASSWORD"); then
      echo "ERROR: failed to create temporary file for PostgreSQL admin password." >&2
      exit 1
    fi
  fi
fi

HELM_ARGS=(upgrade --install "$RELEASE_NAME" "$CHART_PATH" -n "$NAMESPACE" --create-namespace --wait --timeout 10m)

if [ -n "$VALUES_FILE" ]; then
  HELM_ARGS+=( -f "$VALUES_FILE" )
fi

if [ -n "$EXTRA_VALUES_FILE" ]; then
  HELM_ARGS+=( -f "$EXTRA_VALUES_FILE" )
fi

if [ -n "$POSTGRESQL_PASSWORD_FILE" ]; then
  HELM_ARGS+=( --set-file "global.postgresql.auth.password=$POSTGRESQL_PASSWORD_FILE" )
  HELM_ARGS+=( --set-file "keycloak.postgresql.auth.password=$POSTGRESQL_PASSWORD_FILE" )
fi

if [ -n "$POSTGRESQL_ADMIN_PASSWORD_FILE" ]; then
  HELM_ARGS+=( --set-file "global.postgresql.auth.postgresPassword=$POSTGRESQL_ADMIN_PASSWORD_FILE" )
  HELM_ARGS+=( --set-file "keycloak.postgresql.auth.postgresPassword=$POSTGRESQL_ADMIN_PASSWORD_FILE" )
fi

helm "${HELM_ARGS[@]}"
