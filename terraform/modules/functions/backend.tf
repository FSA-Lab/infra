terraform {
  backend "azurerm" {
    # Backend configuration cannot use variables, so we hardcode the values here
    # Since this options do not contain sensitive information, I decide to use hardcode values and push this file to git repository
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "cicdlab05022026tfs"
    container_name       = "tfstate"
    key                  = "modules/functions/terraform.tfstate"
  }
}