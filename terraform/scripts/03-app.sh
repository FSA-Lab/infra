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

MAX_APPLY_ATTEMPTS=3
APPLY_ATTEMPT=1
APPLY_LOG_FILES=()

cleanup_apply_logs() {
  local log_file
  for log_file in "${APPLY_LOG_FILES[@]}"; do
    [ -n "$log_file" ] && [ -f "$log_file" ] && rm -f "$log_file"
  done
}

trap cleanup_apply_logs EXIT

import_from_apply_log() {
  local apply_log=$1
  local candidates
  local imported_any=false
  local import_error_count

  candidates=$(awk '
    /resource with the ID "/ && /already exists - to be managed via Terraform this resource needs to be imported into the State/ {
      match($0, /"[^"]+"/)
      if (RSTART > 0) {
        pending_id = substr($0, RSTART + 1, RLENGTH - 2)
      }
      next
    }
    pending_id != "" && /with [^,]+,/ {
      match($0, /with [^,]+,/)
      if (RSTART > 0) {
        address = substr($0, RSTART + 5, RLENGTH - 6)
        print address "\t" pending_id
      }
      pending_id = ""
    }
  ' "$apply_log")

  if [ -z "$candidates" ]; then
    import_error_count=$(grep -c "already exists - to be managed via Terraform this resource needs to be imported into the State" "$apply_log" || true)
    if [ "$import_error_count" -gt 0 ]; then
      echo "WARN: detected import-required errors but could not parse Terraform output format" >&2
    fi
    return 1
  fi

  while IFS=$'\t' read -r terraform_address resource_id; do
    [ -z "$terraform_address" ] && continue
    [ -z "$resource_id" ] && continue

    if terraform state show "$terraform_address" >/dev/null 2>&1; then
      echo "INFO: already managed in state: $terraform_address" >&2
      continue
    fi

    echo "INFO: importing side-effect resource into state: $terraform_address" >&2
    if terraform import "$terraform_address" "$resource_id"; then
      imported_any=true
    else
      echo "WARN: failed to import $terraform_address ($resource_id)" >&2
    fi
  done <<< "$candidates"

  [ "$imported_any" = true ]
}

while [ "$APPLY_ATTEMPT" -le "$MAX_APPLY_ATTEMPTS" ]; do
  ORIGINAL_UMASK=$(umask)
  umask 077
  APPLY_LOG=$(mktemp "${TMPDIR:-/tmp}/terraform-functions-apply-${APPLY_ATTEMPT}-XXXXXX.log")
  umask "$ORIGINAL_UMASK"
  APPLY_LOG_FILES+=("$APPLY_LOG")
  echo "INFO: terraform apply attempt ${APPLY_ATTEMPT}/${MAX_APPLY_ATTEMPTS}" >&2

  set +e
  terraform apply -auto-approve -no-color 2>&1 | tee "$APPLY_LOG"
  APPLY_EXIT_CODE=${PIPESTATUS[0]}
  set -e

  if [ "$APPLY_EXIT_CODE" -eq 0 ]; then
    exit 0
  fi

  if ! import_from_apply_log "$APPLY_LOG"; then
    exit "$APPLY_EXIT_CODE"
  fi

  APPLY_ATTEMPT=$((APPLY_ATTEMPT + 1))
done

echo "ERROR: terraform apply failed after ${MAX_APPLY_ATTEMPTS} attempts" >&2
exit 1
