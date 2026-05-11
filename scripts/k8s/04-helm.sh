#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
NAMESPACE=${NAMESPACE:-cicd}
CHART_PATH="$ROOT_DIR/config/helm/cicd"
RELEASE_NAME=${RELEASE_NAME:-cicd}
# Matches postgresql.fullnameOverride in values.yaml
POSTGRESQL_RESOURCE_NAME=${POSTGRESQL_RESOURCE_NAME:-postgres}
AKS_RESOURCE_GROUP_NAME=${AKS_RESOURCE_GROUP_NAME:-}
TMP_BASE=${TMPDIR:-/tmp}
ORPHAN_CLEANUP_WAIT_SECONDS=${ORPHAN_CLEANUP_WAIT_SECONDS:-60}
RECREATE_POSTGRESQL_STATEFULSET_ON_IMMUTABLE_ERROR=${RECREATE_POSTGRESQL_STATEFULSET_ON_IMMUTABLE_ERROR:-true}
DELETE_POSTGRESQL_PVCS_ON_IMMUTABLE_ERROR=${DELETE_POSTGRESQL_PVCS_ON_IMMUTABLE_ERROR:-true}
RECOVER_INGRESS_WEBHOOK_CA_ON_TLS_ERROR=${RECOVER_INGRESS_WEBHOOK_CA_ON_TLS_ERROR:-true}
INGRESS_ADMISSION_WEBHOOK_RESOURCE_NAME=${INGRESS_ADMISSION_WEBHOOK_RESOURCE_NAME:-${RELEASE_NAME}-ingress-nginx-admission}
JENKINS_PVC_NAME=${JENKINS_PVC_NAME:-${RELEASE_NAME}-jenkins}
POSTGRESQL_PVC_NAME_PREFIX=${POSTGRESQL_PVC_NAME_PREFIX:-data-${POSTGRESQL_RESOURCE_NAME}-}
INGRESS_VALIDATION_WEBHOOK_NAME=${INGRESS_VALIDATION_WEBHOOK_NAME:-validate.nginx.ingress.kubernetes.io}
SONARQUBE_MONITORING_PASSCODE=${SONARQUBE_MONITORING_PASSCODE:-}
VALUES_FILE=${VALUES_FILE:-}
EXTRA_VALUES_FILE=""

cleanup_temp_files() {
  if [ -n "$EXTRA_VALUES_FILE" ] && [ -f "$EXTRA_VALUES_FILE" ]; then
    rm -f "$EXTRA_VALUES_FILE"
  fi
}
trap cleanup_temp_files EXIT

is_truthy() {
  case "${1:-}" in
    true|1|yes|YES|TRUE) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_extra_values_file() {
  if [ -z "$EXTRA_VALUES_FILE" ]; then
    EXTRA_VALUES_FILE=$(mktemp "${TMP_BASE}/helm-extra-values.XXXXXXXXXX.yaml")
  fi
}

cleanup_orphaned_resource() {
  local kind=$1
  local name=$2
  local wait_seconds="$ORPHAN_CLEANUP_WAIT_SECONDS"

  if ! [[ "$wait_seconds" =~ ^[0-9]+$ ]] || [ "$wait_seconds" -lt 1 ]; then
    echo "ERROR: ORPHAN_CLEANUP_WAIT_SECONDS must be a positive integer; got '$wait_seconds'." >&2
    return 1
  fi

  if ! kubectl -n "$NAMESPACE" get "$kind" "$name" >/dev/null 2>&1; then
    return 0
  fi

  kubectl -n "$NAMESPACE" delete "$kind" "$name" --ignore-not-found
  if ! kubectl -n "$NAMESPACE" wait --for=delete "${kind}/${name}" \
      --timeout="${wait_seconds}s" >/dev/null 2>&1; then
    if kubectl -n "$NAMESPACE" get "$kind" "$name" >/dev/null 2>&1; then
      echo "ERROR: timed out waiting for ${kind}/${name} deletion in namespace $NAMESPACE." >&2
      return 1
    fi
  fi
}

append_jenkins_persistence_overrides() {
  local jenkins_storage_class=""
  local jenkins_size=""

  if ! kubectl -n "$NAMESPACE" get pvc "$JENKINS_PVC_NAME" >/dev/null 2>&1; then
    return 0
  fi

  jenkins_storage_class=$(kubectl -n "$NAMESPACE" get pvc "$JENKINS_PVC_NAME" \
    -o jsonpath='{.spec.storageClassName}' 2>/dev/null || true)
  jenkins_size=$(kubectl -n "$NAMESPACE" get pvc "$JENKINS_PVC_NAME" \
    -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null || true)

  if [ -z "$jenkins_storage_class" ] && [ -z "$jenkins_size" ]; then
    return 0
  fi

  ensure_extra_values_file
  cat >> "$EXTRA_VALUES_FILE" <<YAML
jenkins:
  persistence:
YAML

  if [ -n "$jenkins_storage_class" ]; then
    cat >> "$EXTRA_VALUES_FILE" <<YAML
    storageClass: "$jenkins_storage_class"
YAML
  fi

  if [ -n "$jenkins_size" ]; then
    cat >> "$EXTRA_VALUES_FILE" <<YAML
    size: "$jenkins_size"
YAML
  fi
}

cleanup_postgresql_pvcs() {
  local wait_seconds="$ORPHAN_CLEANUP_WAIT_SECONDS"
  local pvc_name=""
  local pvc_names

  if ! [[ "$wait_seconds" =~ ^[0-9]+$ ]] || [ "$wait_seconds" -lt 1 ]; then
    echo "ERROR: ORPHAN_CLEANUP_WAIT_SECONDS must be a positive integer; got '$wait_seconds'." >&2
    return 1
  fi

  pvc_names=$(kubectl -n "$NAMESPACE" get pvc \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null \
    | awk -v prefix="$POSTGRESQL_PVC_NAME_PREFIX" 'index($0, prefix) == 1' || true)
  if [ -z "$pvc_names" ]; then
    return 0
  fi

  while IFS= read -r pvc_name; do
    [ -z "$pvc_name" ] && continue
    kubectl -n "$NAMESPACE" delete pvc "$pvc_name" --ignore-not-found
    if ! kubectl -n "$NAMESPACE" wait --for=delete "pvc/$pvc_name" \
        --timeout="${wait_seconds}s" >/dev/null 2>&1; then
      if kubectl -n "$NAMESPACE" get pvc "$pvc_name" >/dev/null 2>&1; then
        echo "ERROR: timed out waiting for pvc/$pvc_name deletion in namespace $NAMESPACE." >&2
        return 1
      fi
    fi
  done <<< "$pvc_names"
}

cleanup_ingress_admission_webhooks() {
  if ! kubectl delete validatingwebhookconfiguration \
      "$INGRESS_ADMISSION_WEBHOOK_RESOURCE_NAME" --ignore-not-found >/dev/null 2>&1; then
    echo "WARN: failed to delete validatingwebhookconfiguration/$INGRESS_ADMISSION_WEBHOOK_RESOURCE_NAME during recovery." >&2
  fi
  if ! kubectl delete mutatingwebhookconfiguration \
      "$INGRESS_ADMISSION_WEBHOOK_RESOURCE_NAME" --ignore-not-found >/dev/null 2>&1; then
    echo "WARN: failed to delete mutatingwebhookconfiguration/$INGRESS_ADMISSION_WEBHOOK_RESOURCE_NAME during recovery." >&2
  fi
}

helm dependency update "$CHART_PATH"

if [ -n "$AKS_RESOURCE_GROUP_NAME" ]; then
  ensure_extra_values_file
  cat >> "$EXTRA_VALUES_FILE" <<YAML
ingress-nginx:
  controller:
    service:
      annotations:
        service.beta.kubernetes.io/azure-load-balancer-resource-group: "$AKS_RESOURCE_GROUP_NAME"
YAML
fi

append_jenkins_persistence_overrides

HELM_ARGS=(
  upgrade --install "$RELEASE_NAME" "$CHART_PATH"
  --namespace "$NAMESPACE"
  --create-namespace
  --wait
  --timeout 15m
)

if [ -n "$VALUES_FILE" ]; then
  HELM_ARGS+=( --values "$VALUES_FILE" )
fi

if [ -n "$EXTRA_VALUES_FILE" ]; then
  HELM_ARGS+=( --values "$EXTRA_VALUES_FILE" )
fi

if [ -n "$SONARQUBE_MONITORING_PASSCODE" ]; then
  HELM_ARGS+=( --set "sonarqube.monitoringPasscode=$SONARQUBE_MONITORING_PASSCODE" )
fi

HELM_OUTPUT_FILE=$(mktemp "${TMP_BASE}/helm-upgrade.XXXXXXXXXX.log")

if helm "${HELM_ARGS[@]}" >"$HELM_OUTPUT_FILE" 2>&1; then
  cat "$HELM_OUTPUT_FILE"
  rm -f "$HELM_OUTPUT_FILE"
  exit 0
fi

cat "$HELM_OUTPUT_FILE" >&2

retry_required=false

if is_truthy "$RECREATE_POSTGRESQL_STATEFULSET_ON_IMMUTABLE_ERROR" \
  && grep -Fq "cannot patch" "$HELM_OUTPUT_FILE" \
  && grep -Fq "$POSTGRESQL_RESOURCE_NAME" "$HELM_OUTPUT_FILE" \
  && grep -Fq "with kind StatefulSet" "$HELM_OUTPUT_FILE" \
  && grep -Fq "Forbidden: updates to statefulset spec" "$HELM_OUTPUT_FILE"; then
  echo "WARN: Detected immutable StatefulSet spec change for statefulset/$POSTGRESQL_RESOURCE_NAME." >&2
  echo "WARN: Deleting resources and retrying the Helm upgrade once." >&2
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

  if is_truthy "$DELETE_POSTGRESQL_PVCS_ON_IMMUTABLE_ERROR"; then
    echo "WARN: Deleting PostgreSQL PVCs matching prefix '$POSTGRESQL_PVC_NAME_PREFIX' before retry." >&2
    if ! cleanup_postgresql_pvcs; then
      echo "ERROR: failed to cleanup PostgreSQL PVCs before the Helm retry." >&2
      rm -f "$HELM_OUTPUT_FILE"
      exit 1
    fi
  fi

  retry_required=true
fi

if is_truthy "$RECOVER_INGRESS_WEBHOOK_CA_ON_TLS_ERROR" \
  && grep -Fq "failed calling webhook \"$INGRESS_VALIDATION_WEBHOOK_NAME\"" "$HELM_OUTPUT_FILE" \
  && grep -Fq "x509: certificate signed by unknown authority" "$HELM_OUTPUT_FILE"; then
  echo "WARN: Detected ingress-nginx admission webhook TLS trust failure." >&2
  echo "WARN: Deleting admission webhook configurations and retrying Helm once." >&2
  cleanup_ingress_admission_webhooks
  retry_required=true
fi

if [ "$retry_required" = true ]; then
  if helm "${HELM_ARGS[@]}" >"$HELM_OUTPUT_FILE" 2>&1; then
    cat "$HELM_OUTPUT_FILE"
    rm -f "$HELM_OUTPUT_FILE"
    exit 0
  fi

  cat "$HELM_OUTPUT_FILE" >&2
  echo "ERROR: Helm retry after recovery actions failed." >&2
fi

rm -f "$HELM_OUTPUT_FILE"
exit 1