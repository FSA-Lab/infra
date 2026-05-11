#!/bin/bash
set -euo pipefail

# config/helm/templates/ contains standalone manifests that are applied directly
# by kubectl. They are NOT part of the cicd Helm chart (config/helm/cicd/) and
# are not tracked by Helm, so no release conflicts arise.
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

# Disable to prevent Helm conflicts with manually applied namespace.
# kubectl apply -f "$ROOT_DIR/config/helm/cicd/templates/namespace.yaml"
kubectl apply -f "$ROOT_DIR/config/helm/cicd/templates/rbac.yaml"
