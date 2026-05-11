#!/bin/bash
set -euo pipefail

NAMESPACE=${NAMESPACE:-cicd}

# Credentials injected by the CI workflow (GitHub Actions secrets).
KEYCLOAK_POSTGRESQL_PASSWORD=${KEYCLOAK_POSTGRESQL_PASSWORD:-}
KEYCLOAK_POSTGRESQL_ADMIN_PASSWORD=${KEYCLOAK_POSTGRESQL_ADMIN_PASSWORD:-}
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-}
JENKINS_ADMIN_USER=${JENKINS_ADMIN_USER:-admin}
JENKINS_ADMIN_PASSWORD=${JENKINS_ADMIN_PASSWORD:-}

if [ -z "$KEYCLOAK_POSTGRESQL_PASSWORD" ]; then
  echo "ERROR: KEYCLOAK_POSTGRESQL_PASSWORD is required." >&2
  exit 1
fi
if [ -z "$KEYCLOAK_POSTGRESQL_ADMIN_PASSWORD" ]; then
  echo "ERROR: KEYCLOAK_POSTGRESQL_ADMIN_PASSWORD is required." >&2
  exit 1
fi
if [ -z "$KEYCLOAK_ADMIN_PASSWORD" ]; then
  echo "ERROR: KEYCLOAK_ADMIN_PASSWORD is required." >&2
  exit 1
fi
if [ -z "$JENKINS_ADMIN_PASSWORD" ]; then
  echo "ERROR: JENKINS_ADMIN_PASSWORD is required." >&2
  exit 1
fi

upsert_secret() {
  kubectl -n "$NAMESPACE" create secret generic "$@" \
    --dry-run=client -o yaml | kubectl apply -f -
}

# keycloak-postgresql: shared by PostgreSQL chart, Keycloak, and SonarQube JDBC.
upsert_secret keycloak-postgresql \
  --from-literal=password="$KEYCLOAK_POSTGRESQL_PASSWORD" \
  --from-literal=postgres-password="$KEYCLOAK_POSTGRESQL_ADMIN_PASSWORD"

# keycloak-admin: Keycloak admin bootstrap credentials.
upsert_secret keycloak-admin \
  --from-literal=admin-password="$KEYCLOAK_ADMIN_PASSWORD"

# jenkins-admin: Jenkins initial admin account.
upsert_secret jenkins-admin \
  --from-literal=jenkins-admin-user="$JENKINS_ADMIN_USER" \
  --from-literal=jenkins-admin-password="$JENKINS_ADMIN_PASSWORD"

# jenkins-oidc: Keycloak OIDC client credentials for Jenkins JCasC.
# The client ID is always 'jenkins'. The secret is dynamically fetched from an
# existing cluster secret (stable across re-deploys) or generated fresh and
# stored in the cluster — no repo secret required.
JENKINS_OIDC_CLIENT_ID="jenkins"
JENKINS_OIDC_CLIENT_SECRET=""

if kubectl -n "$NAMESPACE" get secret jenkins-oidc >/dev/null 2>&1; then
  JENKINS_OIDC_CLIENT_SECRET=$(kubectl -n "$NAMESPACE" get secret jenkins-oidc \
    -o jsonpath='{.data.client-secret}' 2>/dev/null \
    | base64 --decode 2>/dev/null || true)
fi

if [ -z "$JENKINS_OIDC_CLIENT_SECRET" ]; then
  JENKINS_OIDC_CLIENT_SECRET=$(openssl rand -base64 64)
  echo "INFO: Generated new OIDC client secret for Jenkins." >&2
fi

upsert_secret jenkins-oidc \
  --from-literal=client-id="$JENKINS_OIDC_CLIENT_ID" \
  --from-literal=client-secret="$JENKINS_OIDC_CLIENT_SECRET"
