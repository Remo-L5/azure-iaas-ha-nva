variable "subscription_id" {
  description = "The ID of the Azure subscription"
  type        = string
}

variable "location" {
  description = "The location of the resources"
  type        = string
}

variable "environment" {
  description = "The environment of the deployment (e.g., dev, prod)"
  type        = string
}