# Provisioning Tasks

## Task 0. Setup tools

1. Install TFLint

> curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

Then run `tflint --init`

2. Run `terraform init` per environment.

## Task 1. Setup tfstate storage

1. Create remote data sources (Azure Blob Storage), with versioning enabled.
2. Configure Terraform to use ABS as remote backend.
3. Ensure no tfstate exist locally.

## Task 2. Secure needed service quotas

1. AKS with enough resource allocation.
2. Other Azure services if needed.
3. Other provider services if needed.

## Task 3. Configure Terraform

## Task 4. Tracking infrastructure

- For code/configuration, use Git
- For state, use Blob Storage

# Notes

1. Sub-modules should be placed in its own file or directory.
2. Sub-modules should reuse root `providers.tf` and `versions.tf` (symbolic link or copy).
3. Root directory only contains `providers.tf` and `versions.tf` for the purpose of defining global providers and versions. Terraform should not be executed in root directory, but in sub-module directories.
4. Feel free to use local set of `providers.tf` and `versions.tf` in sub-module directories if there are specific provider or version requirements for that module.

# Workflow

1. `cd terraform/modules/<module_name>`
2. `terraform init`
3. `terraform plan -out=<optional_plan_file>`
4. `terraform apply <optional_plan_file>`

# Module activation order

1. `backend` (should be activated only if the remote `backend` is not yet created)
<!-- 2. `aks` (requires `backend`) -->
