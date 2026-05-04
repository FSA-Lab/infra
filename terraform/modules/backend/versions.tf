terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.70.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.8.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "=2.8.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "=3.2.4"
    }
    time = {
      source  = "hashicorp/time"
      version = "=0.13.1"
    }
  }
}
