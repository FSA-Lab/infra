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
ORPHAN_CLEANUP_WAIT_SECONDS=${ORPHAN_CLEANUP_WAIT_SECONDS:-60}
RECREATE_POSTGRESQL_STATEFULSET_ON_IMMUTABLE_ERROR=${RECREATE_POSTGRESQL_STATEFULSET_ON_IMMUTABLE_ERROR:-true}
EXTRA_VALUES_FILE=""
POSTGRESQL_PASSWORD=""
POSTGRESQL_ADMIN_PASSWORD=""
REMOTE_POSTGRESQL_PASSWORD=${KEYCLOAK_POSTGRESQL_PASSWORD:-}
REMOTE_POSTGRESQL_ADMIN_PASSWORD=${KEYCLOAK_POSTGRESQL_ADMIN_PASSWORD:-}
KEYVAULT_NAME=${KEYVAULT_NAME:-${AZURE_KEYVAULT_NAME:-}}
KEYVAULT_POSTGRESQL_PASSWORD_SECRET_NAME=${KEYVAULT_POSTGRESQL_PASSWORD_SECRET_NAME:-keycloak-postgresql-password}
KEYVAULT_POSTGRESQL_ADMIN_PASSWORD_SECRET_NAME=${KEYVAULT_POSTGRESQL_ADMIN_PASSWORD_SECRET_NAME:-keycloak-postgresql-admin-password}
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
  local wait_seconds="$ORPHAN_CLEANUP_WAIT_SECONDS"

  if [ -z "$kind" ] || [ -z "$name" ]; then
    echo "ERROR: cleanup_orphaned_resource requires kind and name." >&2
    return 1
  fi

  if ! [[ "$wait_seconds" =~ ^[0-9]+$ ]] || [ "$wait_seconds" -lt 1 ]; then
    echo "ERROR: ORPHAN_CLEANUP_WAIT_SECONDS must be a positive integer; got '$wait_seconds'." >&2
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

  if ! kubectl -n "$NAMESPACE" wait --for=delete "$kind/$name" --timeout="${wait_seconds}s" >/dev/null 2>&1; then
    if kubectl -n "$NAMESPACE" get "$kind" "$name" >/dev/null 2>&1; then
      echo "ERROR: timed out waiting for $kind/$name deletion in namespace $NAMESPACE." >&2
      return 1
    fi
  fi
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

is_truthy() {
  local value=${1:-}
  case "$value" in
    [Tt][Rr][Uu][Ee]|1|[Yy][Ee][Ss]|[Yy]|[Oo][Nn])
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

get_keyvault_secret_value() {
  local secret_name=${1:-}
  local value=""

  if [ -z "$secret_name" ] || [ -z "$KEYVAULT_NAME" ]; then
    return 0
  fi

  if ! command -v az >/dev/null 2>&1; then
    return 0
  fi

  if ! value=$(az keyvault secret show --vault-name "$KEYVAULT_NAME" --name "$secret_name" --query value -o tsv 2>/dev/null); then
    value=""
  fi

  printf '%s' "$value"
}

upsert_keyvault_secret_if_missing() {
  local secret_name=${1:-}
  local secret_value=${2:-}

  if [ -z "$secret_name" ] || [ -z "$secret_value" ] || [ -z "$KEYVAULT_NAME" ]; then
    return 0
  fi

  if ! command -v az >/dev/null 2>&1; then
    return 0
  fi

  if az keyvault secret show --vault-name "$KEYVAULT_NAME" --name "$secret_name" >/dev/null 2>&1; then
    return 0
  fi

  if az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "$secret_name" --value "$secret_value" >/dev/null 2>&1; then
    echo "INFO: persisted missing secret '$secret_name' to Key Vault '$KEYVAULT_NAME'." >&2
  else
    echo "WARN: failed to persist secret '$secret_name' to Key Vault '$KEYVAULT_NAME'; continuing." >&2
  fi
}

upsert_postgresql_secret() {
  if [ -z "$POSTGRESQL_PASSWORD" ] || [ -z "$POSTGRESQL_ADMIN_PASSWORD" ]; then
    return 1
  fi

  kubectl -n "$NAMESPACE" create secret generic "$POSTGRESQL_SECRET_NAME" \
    --from-literal=password="$POSTGRESQL_PASSWORD" \
    --from-literal=postgres-password="$POSTGRESQL_ADMIN_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
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

if [ -z "$POSTGRESQL_PASSWORD" ] && [ -n "$REMOTE_POSTGRESQL_PASSWORD" ]; then
  POSTGRESQL_PASSWORD="$REMOTE_POSTGRESQL_PASSWORD"
fi

if [ -z "$POSTGRESQL_ADMIN_PASSWORD" ] && [ -n "$REMOTE_POSTGRESQL_ADMIN_PASSWORD" ]; then
  POSTGRESQL_ADMIN_PASSWORD="$REMOTE_POSTGRESQL_ADMIN_PASSWORD"
fi

if [ -z "$POSTGRESQL_PASSWORD" ]; then
  POSTGRESQL_PASSWORD=$(get_keyvault_secret_value "$KEYVAULT_POSTGRESQL_PASSWORD_SECRET_NAME")
fi

if [ -z "$POSTGRESQL_ADMIN_PASSWORD" ]; then
  POSTGRESQL_ADMIN_PASSWORD=$(get_keyvault_secret_value "$KEYVAULT_POSTGRESQL_ADMIN_PASSWORD_SECRET_NAME")
fi

if [ -z "$POSTGRESQL_ADMIN_PASSWORD" ] && [ -n "$POSTGRESQL_PASSWORD" ]; then
  POSTGRESQL_ADMIN_PASSWORD="$POSTGRESQL_PASSWORD"
fi

if [ -z "$POSTGRESQL_PASSWORD" ] && [ -n "$POSTGRESQL_ADMIN_PASSWORD" ]; then
  POSTGRESQL_PASSWORD="$POSTGRESQL_ADMIN_PASSWORD"
fi

if [ -z "$POSTGRESQL_PASSWORD" ] || [ -z "$POSTGRESQL_ADMIN_PASSWORD" ]; then
  echo "ERROR: persistent PostgreSQL credentials are required for Keycloak chart upgrades." >&2
  echo "Provide one of: secret/$POSTGRESQL_SECRET_NAME in namespace '$NAMESPACE', Key Vault secrets via KEYVAULT_NAME, or CI secret env vars KEYCLOAK_POSTGRESQL_PASSWORD and KEYCLOAK_POSTGRESQL_ADMIN_PASSWORD." >&2
  exit 1
fi

if ! upsert_postgresql_secret; then
  echo "ERROR: failed to upsert secret/$POSTGRESQL_SECRET_NAME in namespace '$NAMESPACE'." >&2
  exit 1
fi

upsert_keyvault_secret_if_missing "$KEYVAULT_POSTGRESQL_PASSWORD_SECRET_NAME" "$POSTGRESQL_PASSWORD"
upsert_keyvault_secret_if_missing "$KEYVAULT_POSTGRESQL_ADMIN_PASSWORD_SECRET_NAME" "$POSTGRESQL_ADMIN_PASSWORD"

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

HELM_OUTPUT_FILE=$(mktemp "${TMP_BASE}/helm-upgrade.XXXXXXXXXX.log")

if helm "${HELM_ARGS[@]}" >"$HELM_OUTPUT_FILE" 2>&1; then
  cat "$HELM_OUTPUT_FILE"
  rm -f "$HELM_OUTPUT_FILE"
  exit 0
fi

cat "$HELM_OUTPUT_FILE" >&2

if is_truthy "$RECREATE_POSTGRESQL_STATEFULSET_ON_IMMUTABLE_ERROR" \
  && grep -Fq "cannot patch" "$HELM_OUTPUT_FILE" \
  && grep -Fq "$POSTGRESQL_RESOURCE_NAME" "$HELM_OUTPUT_FILE" \
  && grep -Fq "with kind StatefulSet" "$HELM_OUTPUT_FILE" \
  && grep -Fq "Forbidden: updates to statefulset spec" "$HELM_OUTPUT_FILE"; then
  echo "WARN: Detected immutable StatefulSet spec change for statefulset/$POSTGRESQL_RESOURCE_NAME." >&2
  echo "WARN: Deleting resources and retrying the Helm upgrade once with --force (PVC data retention depends on storage class and reclaim policy)." >&2
  if ! cleanup_orphaned_resource statefulset "$POSTGRESQL_RESOURCE_NAME"; then
    echo "ERROR: failed to cleanup statefulset/$POSTGRESQL_RESOURCE_NAME before the Helm retry." >&2
    rm -f "$HELM_OUTPUT_FILE"
    exit 1
  fi
  if ! cleanup_orphaned_resource service "$POSTGRESQL_RESOURCE_NAME"; then
    echo "ERROR: failed to cleanup service/$POSTGRESQL_RESOURCE_NAME before the Helm retry." >&2
    rm -f "$HELM_OUTPUT_FILE"
    exit 1
  fi

  HELM_FORCE_ARGS=( "${HELM_ARGS[@]}" --force )
  if helm "${HELM_FORCE_ARGS[@]}" >"$HELM_OUTPUT_FILE" 2>&1; then
    cat "$HELM_OUTPUT_FILE"
    rm -f "$HELM_OUTPUT_FILE"
    exit 0
  fi

  cat "$HELM_OUTPUT_FILE" >&2
  echo "ERROR: Helm retry after StatefulSet recreation failed (including --force)." >&2
fi

rm -f "$HELM_OUTPUT_FILE"
exit 1
