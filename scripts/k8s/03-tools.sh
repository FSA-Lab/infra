#!/bin/bash
set -euo pipefail

# BuildKit and Trivy are now deployed as sidecar containers in Jenkins agent pods
# via the Helm chart (config/helm/cicd/values.yaml). No standalone manifests to apply.
echo "INFO: BuildKit and Trivy are managed by the Helm chart as Jenkins agent sidecar containers." >&2
