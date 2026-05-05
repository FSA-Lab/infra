#!/bin/bash
set -e pipefail

# DESCRIPTION:
# This script is used to deploy all base modules in the correct order.

# PREREQUISITES:
# - Azure CLI installed and logged in
# - Terraform installed
# - The necessary environment variables set (e.g., ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID)
# - "Backend" has been deployed separately

# This script is used to deploy all modules in the correct order. 
HOME_DIR=$(pwd)

echo "Base infrastructure should have been deployed to Azure."