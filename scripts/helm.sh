#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

bash "$ROOT_DIR/scripts/k8s/00-deploy-cicd.sh"
