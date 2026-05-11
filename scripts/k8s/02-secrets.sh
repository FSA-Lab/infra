#!/bin/bash
set -euo pipefail

NAMESPACE=${NAMESPACE:-cicd}

# Credentials injected by the CI workflow (GitHub Actions secrets/vars).
KEYCLOAK_POSTGRESQL_PASSWORD=${KEYCLOAK_POSTGRESQL_PASSWORD:-}
KEYCLOAK_POSTGRESQL_ADMIN_PASSWORD=${KEYCLOAK_POSTGRESQL_ADMIN_PASSWORD:-}
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-}
JENKINS_ADMIN_USER=${JENKINS_ADMIN_USER:-admin}
JENKINS_ADMIN_PASSWORD=${JENKINS_ADMIN_PASSWORD:-}
JENKINS_OIDC_CLIENT_ID=${JENKINS_OIDC_CLIENT_ID:-jenkins}
JENKINS_OIDC_CLIENT_SECRET=${JENKINS_OIDC_CLIENT_SECRET:-}

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

# jenkins-oidc: Keycloak OIDC client used by Jenkins JCasC (optional at deploy time).
if [ -n "$JENKINS_OIDC_CLIENT_SECRET" ]; then
  upsert_secret jenkins-oidc \
    --from-literal=client-id="$JENKINS_OIDC_CLIENT_ID" \
    --from-literal=client-secret="$JENKINS_OIDC_CLIENT_SECRET"
else
  echo "INFO: JENKINS_OIDC_CLIENT_SECRET not set; skipping jenkins-oidc secret creation." >&2
fi
