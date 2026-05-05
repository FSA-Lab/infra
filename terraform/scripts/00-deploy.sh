#!/bin/bash
set -e pipefail

# This script is used to deploy Azure infrastructure using Terraform.

DISPOSABle=true # This variable controls whether to destroy the infrastructure before deploying (excluding the remote state backend). Set to true currently for faster prototyping.

# By default, run 01-base.sh, 02-aks.sh, and 03-app.sh sequentially.
echo "Deploying base infrastructure..."
bash $HOME_DIR/terraform/scripts/01-base.sh

echo "Deploying AKS cluster..."
bash $HOME_DIR/terraform/scripts/02-aks.sh

echo "Deploying app services..."
bash $HOME_DIR/terraform/scripts/03-app.sh