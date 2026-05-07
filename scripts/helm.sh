#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAMESPACE=${NAMESPACE:-cicd}
CHART_PATH="$ROOT_DIR/config/helm/cicd-platform"
VALUES_FILE=${VALUES_FILE:-}

kubectl apply -f "$ROOT_DIR/config/k8s/namespace.yaml"
kubectl apply -f "$ROOT_DIR/config/k8s/workload-placement.yaml"
kubectl apply -f "$ROOT_DIR/config/k8s/keyvault-secrets.yaml"
kubectl apply -f "$ROOT_DIR/config/k8s/buildkit.yaml"
kubectl apply -f "$ROOT_DIR/config/k8s/trivy.yaml"

helm dependency update "$CHART_PATH"

if [ -n "$VALUES_FILE" ]; then
  helm upgrade --install cicd-platform "$CHART_PATH" -n "$NAMESPACE" --create-namespace -f "$VALUES_FILE"
else
  helm upgrade --install cicd-platform "$CHART_PATH" -n "$NAMESPACE" --create-namespace
fi
