#!/bin/bash
set -e pipefail

# DESCRIPTION: 
# This script is used to deploy AKS cluster. 
#
# PREREQUISITES:
# 00-deploy-base.sh

HOME_DIR=$(pwd)

# Deploy the AKS module
cd $HOME_DIR/terraform/modules/aks
# terraform init
# terraform apply -auto-approve

echo "AKS cluster should have been deployed to Azure."