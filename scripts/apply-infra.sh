#!/bin/bash
set -e pipefail

ROOT_DIR=$(pwd)

# Call terraform/scripts/deploy.sh to deploy the infrastructure
bash $ROOT_DIR/terraform/scripts/00-deploy.sh

## Infra is up, including the AKS cluster. 

# Call helm.sh to deploy the helm charts to the AKS cluster
bash $ROOT_DIR/scripts/helm.sh

