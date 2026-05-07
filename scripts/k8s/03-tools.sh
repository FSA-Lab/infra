#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

kubectl apply -f "$ROOT_DIR/config/k8s/buildkit.yaml"
kubectl apply -f "$ROOT_DIR/config/k8s/trivy.yaml"
