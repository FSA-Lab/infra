#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CHART_PATH="$ROOT_DIR/config/helm/cicd"

: "${DNS_ROOT:?DNS_ROOT is required}"
: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}"

CERT_MANAGER_EMAIL="${CERT_MANAGER_EMAIL:-cert-manager@${DNS_ROOT}}"

################################################################################
# AKS kubeconfig
################################################################################

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

helm dep update "$CHART_PATH"

################################################################################
# cert-manager CRDs (idempotent)
################################################################################

kubectl apply -f \
  https://github.com/cert-manager/cert-manager/releases/download/v1.19.5/cert-manager.crds.yaml

################################################################################
# cert-manager
################################################################################

# Remove old webhook configurations to avoid upgrade issues. 
kubectl delete validatingwebhookconfiguration cert-manager-webhook \
  --ignore-not-found=true

kubectl delete mutatingwebhookconfiguration cert-manager-webhook \
  --ignore-not-found=true

# kubectl delete validatingwebhookconfiguration cicd-cert-manager-webhook \
#   --ignore-not-found=true

# kubectl delete mutatingwebhookconfiguration cicd-cert-manager-webhook \
#   --ignore-not-found=true

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=false \
  --wait

################################################################################
# Wait for webhook readiness
################################################################################

kubectl rollout status deployment/cert-manager-webhook \
  -n cert-manager \
  --timeout=5m

################################################################################
# CICD platform
################################################################################

FQDN_TEMPLATE="{{.Name}}.${DNS_ROOT}"

helm upgrade --install cicd "$CHART_PATH" \
  -n cicd \
  --create-namespace \
  --timeout 15m \
  --set global.domain="$DNS_ROOT" \
  --set certManagerConfig.clusterIssuer.email="$CERT_MANAGER_EMAIL" \
  --set external-dns.domainFilters[0]="$DNS_ROOT" \
  --set-json 'external-dns.fqdnTemplates=["{{.Name}}.'"${DNS_ROOT}"'"]' \
  --set secrets.postgresql.password="$KEYCLOAK_POSTGRESQL_PASSWORD" \
  --set secrets.postgresql.postgresPassword="$KEYCLOAK_POSTGRESQL_ADMIN_PASSWORD" \
  --set secrets.keycloak.adminPassword="$KEYCLOAK_ADMIN_PASSWORD" \
  --set secrets.jenkins.adminPassword="$JENKINS_ADMIN_PASSWORD" \
  --set secrets.jenkins.oidc.clientSecret="$JENKINS_OIDC_CLIENT_SECRET" \
  --set secrets.cloudflare.apiToken="$CLOUDFLARE_API_TOKEN"