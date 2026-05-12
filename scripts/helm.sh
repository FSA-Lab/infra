#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CHART_PATH="$ROOT_DIR/config/helm/cicd"

: "${DNS_ROOT:?DNS_ROOT is required}"
: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}"
: "${JENKINS_ADMIN_USER:?JENKINS_ADMIN_USER is required}"
: "${KEYCLOAK_ADMIN_USER:?KEYCLOAK_ADMIN_USER is required}"
: "${SONARQUBE_MONITORING_PASSCODE:?SONARQUBE_MONITORING_PASSCODE is required}"

CERT_MANAGER_EMAIL="${CERT_MANAGER_EMAIL:-cert-manager@${DNS_ROOT}}"
SONARQUBE_ADMIN_PASSWORD="${SONARQUBE_ADMIN_PASSWORD:-}"
SONARQUBE_CURRENT_ADMIN_PASSWORD="${SONARQUBE_CURRENT_ADMIN_PASSWORD:-}"
PLATFORM_DOMAIN="cicdlab.${DNS_ROOT}" 

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

kubectl delete validatingwebhookconfiguration cicd-cert-manager-webhook \
  --ignore-not-found=true

kubectl delete mutatingwebhookconfiguration cicd-cert-manager-webhook \
  --ignore-not-found=true

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
# Copy Cloudflare secret to cert-manager namespace (required by ClusterIssuer)
################################################################################

kubectl create secret generic cloudflare-provider-credentials \
  --namespace cert-manager \
  --from-literal=api-token="$CLOUDFLARE_API_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

################################################################################
# CICD platform
################################################################################

FQDN_TEMPLATE="{{.Name}}.${DNS_ROOT}"

helm_args=(
  --set global.domain="$PLATFORM_DOMAIN"                                    # was DNS_ROOT
  --set certManagerConfig.clusterIssuer.email="$CERT_MANAGER_EMAIL"
  --set external-dns.domainFilters[0]="$DNS_ROOT"                           # keep root
  --set jenkins.controller.ingress.hostName="jenkins.${PLATFORM_DOMAIN}"   # was DNS_ROOT
  --set sonarqube.ingress.hosts[0].name="sonarqube.${PLATFORM_DOMAIN}"     # was DNS_ROOT
  --set sonarqube.ingress.tls[0].hosts[0]="sonarqube.${PLATFORM_DOMAIN}"   # was DNS_ROOT
  --set secrets.postgresql.password="$KEYCLOAK_POSTGRESQL_PASSWORD"
  --set secrets.postgresql.postgresPassword="$KEYCLOAK_POSTGRESQL_ADMIN_PASSWORD"
  --set secrets.keycloak.adminUser="$KEYCLOAK_ADMIN_USER"
  --set secrets.keycloak.adminPassword="$KEYCLOAK_ADMIN_PASSWORD"
  --set secrets.jenkins.adminUser="$JENKINS_ADMIN_USER"
  --set secrets.jenkins.adminPassword="$JENKINS_ADMIN_PASSWORD"
  --set secrets.jenkins.oidc.clientSecret="$JENKINS_OIDC_CLIENT_SECRET"
  --set secrets.sonarqube.monitoringPasscode="$SONARQUBE_MONITORING_PASSCODE"
  --set secrets.cloudflare.apiToken="$CLOUDFLARE_API_TOKEN"
)

if [[ -n "$SONARQUBE_ADMIN_PASSWORD" ]]; then
  : "${SONARQUBE_CURRENT_ADMIN_PASSWORD:?SONARQUBE_CURRENT_ADMIN_PASSWORD is required when SONARQUBE_ADMIN_PASSWORD is set (needed as current admin password for SonarQube password rotation)}"
  helm_args+=(
    --set secrets.sonarqube.adminPassword="$SONARQUBE_ADMIN_PASSWORD"
    --set secrets.sonarqube.currentAdminPassword="$SONARQUBE_CURRENT_ADMIN_PASSWORD"
    --set sonarqube.setAdminPassword.passwordSecretName="sonarqube-admin-password"
  )
fi

helm upgrade --install cicd "$CHART_PATH" \
  -n cicd \
  --create-namespace \
  --timeout 15m \
  "${helm_args[@]}"

  # --set-json 'external-dns.fqdnTemplates=["{{.Name}}.'"${DNS_ROOT}"'"]' \ # all ingresses has explicit hostnames
  # --set-string ingress-nginx.controller.service.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname="jenkins.${DNS_ROOT}\,sonarqube.${DNS_ROOT}\,keycloak.${DNS_ROOT}" \ # removed to exclude ingress-nginx from external-dns management, as it only manages the default backend service which doesn't have a stable hostname and is not intended to be exposed externally
