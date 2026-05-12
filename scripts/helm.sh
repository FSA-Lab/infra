#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CHART_PATH="$ROOT_DIR/config/helm/cicd"

: "${DNS_ROOT:?DNS_ROOT is required}"
: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}"

CERT_MANAGER_EMAIL="${CERT_MANAGER_EMAIL:-cert-manager@${DNS_ROOT}}"

# If AKS cluster info is available, refresh kubeconfig into a temporary file
if [[ -n "${TF_VAR_AKS_NAME:-}" && -n "${TF_VAR_AKS_RESOURCE_GROUP_NAME:-}" ]]; then
  KUBECONFIG_TMP=$(mktemp)
  export KUBECONFIG="${KUBECONFIG_TMP}"

  cleanup() {
    rm -f "${KUBECONFIG_TMP}"
  }
  trap cleanup EXIT

  az aks get-credentials \
    --resource-group "${TF_VAR_AKS_RESOURCE_GROUP_NAME}" \
    --name "${TF_VAR_AKS_NAME}" \
    --file "${KUBECONFIG_TMP}" \
    --admin \
    --overwrite \
    --only-show-errors
fi

helm dep up "$CHART_PATH"

helm upgrade --install cicd "$CHART_PATH" \
  -n cicd \
  --create-namespace \
  --timeout 15m \
  --set global.domain="$DNS_ROOT" \
  --set certManagerConfig.clusterIssuer.email="$CERT_MANAGER_EMAIL" \
  --set external-dns.domainFilters[0]="$DNS_ROOT" \
  --set external-dns.fqdnTemplates[0]="{{.Name}}.${DNS_ROOT}" \
  --set secrets.postgresql.password="$KEYCLOAK_POSTGRESQL_PASSWORD" \
  --set secrets.postgresql.postgresPassword="$KEYCLOAK_POSTGRESQL_ADMIN_PASSWORD" \
  --set secrets.keycloak.adminPassword="$KEYCLOAK_ADMIN_PASSWORD" \
  --set secrets.jenkins.adminPassword="$JENKINS_ADMIN_PASSWORD" \
  --set secrets.jenkins.oidc.clientSecret="$JENKINS_OIDC_CLIENT_SECRET" \
  --set secrets.cloudflare.apiToken="$CLOUDFLARE_API_TOKEN"
