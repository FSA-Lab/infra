#!/bin/bash
set -euo pipefail

# This script is used to install helm and add the necessary repos for the project.

cd config/helm/cicd

helm dependency update

helm upgrade --install cicd . \
  -n cicd \
  --create-namespace