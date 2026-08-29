variable "resource_group_location" {
  type        = string
  description = "Location of the resource group."
}

variable "ARM_SUBSCRIPTION_ID" {
  type        = string
  description = "The Azure Subscription ID"
}

variable "environment" {
  type = string
}