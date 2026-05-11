#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CHART_PATH="$ROOT_DIR/config/helm/cicd"

helm upgrade --install cicd "$CHART_PATH" \
  -n cicd \
  --create-namespace \
  --wait \
  --timeout 15m \
  --set secrets.postgresql.password="$KEYCLOAK_POSTGRESQL_PASSWORD" \
  --set secrets.postgresql.postgresPassword="$KEYCLOAK_POSTGRESQL_ADMIN_PASSWORD" \
  --set secrets.keycloak.adminPassword="$KEYCLOAK_ADMIN_PASSWORD" \
  --set secrets.jenkins.adminPassword="$JENKINS_ADMIN_PASSWORD" \
  --set secrets.jenkins.oidc.clientSecret="$JENKINS_OIDC_CLIENT_SECRET"