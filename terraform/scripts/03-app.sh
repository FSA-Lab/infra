#!/bin/bash
set -e pipefail

# DESCRIPTION:
# This script is used to deploy all app functions to Azure.
#
# PREREQUISITES:
# 00-deploy-base.sh

HOME_DIR=$(pwd)

# Deploy the Functions module
cd $HOME_DIR/terraform/modules/functions
terraform init
terraform apply -auto-approve