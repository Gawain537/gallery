terraform {
  required_version = ">=1.0"

  #backend "azurerm" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.80.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.ARM_SUBSCRIPTION_ID
  features {}
}

locals {
  default_tags = {
    environment = var.environment
    application = "myapp"
    managed_by  = "terraform"
  }
}
