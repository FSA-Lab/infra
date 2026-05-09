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

SUBSCRIPTION_ID=${ARM_SUBSCRIPTION_ID:-${AZURE_SUBSCRIPTION_ID:-}}
if [ -z "$SUBSCRIPTION_ID" ] && command -v az >/dev/null 2>&1; then
  SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || true)
  if [ -z "$SUBSCRIPTION_ID" ]; then
    echo "WARN: unable to determine subscription ID from Azure CLI; import precheck may be skipped" >&2
  fi
fi

if [ -n "${TF_VAR_FUNCTIONS_RESOURCE_GROUP_NAME:-}" ] && [ -n "$SUBSCRIPTION_ID" ]; then
  RG_NAME="$TF_VAR_FUNCTIONS_RESOURCE_GROUP_NAME"
  SA_NAME="${TF_VAR_FUNCTIONS_STORAGE_ACCOUNT_NAME:-}"
  PG_NAME="${TF_VAR_FUNCTIONS_POSTGRES_SERVER_NAME:-}"
  SB_NAME="${TF_VAR_FUNCTIONS_SERVICEBUS_NAMESPACE_NAME:-}"
  FA_NAME="${TF_VAR_FUNCTIONS_FUNCTION_APP_NAME:-}"

  import_diagnostic_setting_if_exists() {
    local address=$1
    local resource_id=$2
    local output

    if output=$(terraform import "$address" "$resource_id" 2>&1); then
      echo "INFO: imported existing diagnostic setting into state: $address" >&2
    else
      if terraform state show "$address" >/dev/null 2>&1; then
        echo "INFO: diagnostic setting already managed in state: $address" >&2
      elif echo "$output" | grep -qi "Cannot import non-existent remote object"; then
        echo "INFO: diagnostic setting not found remotely yet, continuing: $address" >&2
      else
        echo "WARN: import attempt failed for $address; continuing to terraform apply" >&2
        echo "$output" >&2
      fi
    fi
  }

  if [ -n "$SA_NAME" ]; then
    import_diagnostic_setting_if_exists \
      "azurerm_monitor_diagnostic_setting.storage" \
      "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Storage/storageAccounts/$SA_NAME|diag-storage"
  fi

  if [ -n "$PG_NAME" ]; then
    import_diagnostic_setting_if_exists \
      "azurerm_monitor_diagnostic_setting.postgres" \
      "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.DBforPostgreSQL/flexibleServers/$PG_NAME|diag-postgres"
  fi

  if [ -n "$SB_NAME" ]; then
    import_diagnostic_setting_if_exists \
      "azurerm_monitor_diagnostic_setting.servicebus" \
      "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.ServiceBus/namespaces/$SB_NAME|diag-servicebus"
  fi

  if [ -n "$FA_NAME" ]; then
    import_diagnostic_setting_if_exists \
      "azurerm_monitor_diagnostic_setting.function_app" \
      "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Web/sites/$FA_NAME|diag-function-app"
  fi
fi

if [ -z "$SUBSCRIPTION_ID" ]; then
  echo "WARN: subscription ID not detected; skipping diagnostic-setting import precheck." >&2
fi

terraform apply -auto-approve
