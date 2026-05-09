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

DETECTED_SUBSCRIPTION_ID=${ARM_SUBSCRIPTION_ID:-${AZURE_SUBSCRIPTION_ID:-}}
if [ -z "$DETECTED_SUBSCRIPTION_ID" ] && command -v az >/dev/null 2>&1; then
  DETECTED_SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || true)
  if [ -z "$DETECTED_SUBSCRIPTION_ID" ]; then
    echo "WARN: unable to determine subscription ID from Azure CLI; import precheck may be skipped" >&2
  fi
fi

if [ -n "${TF_VAR_FUNCTIONS_RESOURCE_GROUP_NAME:-}" ] && [ -n "$DETECTED_SUBSCRIPTION_ID" ]; then
  RG_NAME="$TF_VAR_FUNCTIONS_RESOURCE_GROUP_NAME"
  STORAGE_ACCOUNT_NAME="${TF_VAR_FUNCTIONS_STORAGE_ACCOUNT_NAME:-}"
  POSTGRES_SERVER_NAME="${TF_VAR_FUNCTIONS_POSTGRES_SERVER_NAME:-}"
  SERVICEBUS_NAMESPACE_NAME="${TF_VAR_FUNCTIONS_SERVICEBUS_NAMESPACE_NAME:-}"
  FUNCTION_APP_NAME="${TF_VAR_FUNCTIONS_FUNCTION_APP_NAME:-}"

  import_diagnostic_setting_if_exists() {
    local terraform_address=$1
    local resource_id=$2
    local import_output

    if import_output=$(terraform import "$terraform_address" "$resource_id" 2>&1); then
      echo "INFO: imported existing diagnostic setting into state: $terraform_address" >&2
    else
      if terraform state show "$terraform_address" >/dev/null 2>&1; then
        echo "INFO: diagnostic setting already managed in state: $terraform_address" >&2
      elif echo "$import_output" | grep -qi "Cannot import non-existent remote object"; then
        echo "INFO: diagnostic setting not found remotely yet, continuing: $terraform_address" >&2
      else
        echo "WARN: import attempt failed for $terraform_address; continuing to terraform apply" >&2
        echo "$import_output" >&2
      fi
    fi
  }

  if [ -n "$STORAGE_ACCOUNT_NAME" ]; then
    import_diagnostic_setting_if_exists \
      "azurerm_monitor_diagnostic_setting.storage" \
      "/subscriptions/$DETECTED_SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME|diag-storage"
  fi

  if [ -n "$POSTGRES_SERVER_NAME" ]; then
    import_diagnostic_setting_if_exists \
      "azurerm_monitor_diagnostic_setting.postgres" \
      "/subscriptions/$DETECTED_SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.DBforPostgreSQL/flexibleServers/$POSTGRES_SERVER_NAME|diag-postgres"
  fi

  if [ -n "$SERVICEBUS_NAMESPACE_NAME" ]; then
    import_diagnostic_setting_if_exists \
      "azurerm_monitor_diagnostic_setting.servicebus" \
      "/subscriptions/$DETECTED_SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.ServiceBus/namespaces/$SERVICEBUS_NAMESPACE_NAME|diag-servicebus"
  fi

  if [ -n "$FUNCTION_APP_NAME" ]; then
    import_diagnostic_setting_if_exists \
      "azurerm_monitor_diagnostic_setting.function_app" \
      "/subscriptions/$DETECTED_SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Web/sites/$FUNCTION_APP_NAME|diag-function-app"
  fi
fi

terraform apply -auto-approve
