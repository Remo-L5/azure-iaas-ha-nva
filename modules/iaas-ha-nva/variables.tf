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

variable "app_short_name" {
  description = "The name of the component"
  type        = string
}

variable "sku_size" {
  description = "The SKU size of the virtual machine"
  type        = string
  default     = "Standard_DS1_v2"
}

variable "os_type" {
  description = "The OS type of the virtual machine"
  type        = string
  default     = "Linux"

}

variable "os_image" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    plan      = string
    version   = string
  })
  description = "The OS image to use for the virtual machine"
}

variable "node_configuration" {
  description = "The configuration for the nodes in the deployment"
  type = map(object({
    availability_zone = number
    sequence_suffix   = string
  }))
}

variable "trust_private_ip_subnet_resource_id" {
  description = "The resource ID of the trusted private IP subnet"
  type        = string
}

variable "untrust_private_ip_subnet_resource_id" {
  description = "The resource ID of the untrusted private IP subnet"
  type        = string
}

variable "mgmt_private_ip_subnet_resource_id" {
  description = "The resource ID of the untrusted private IP subnet"
  type        = string
}

variable "keyvault_resource_id" {
  description = "The resource ID of the Key Vault to store the admin password"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}

}

variable "enable_telemetry" {
  description = "Enable telemetry for the virtual machines"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_resource_id" {
  description = "The resource ID of the Log Analytics workspace for diagnostic logs and monitoring"
  type        = string
  default     = null
}

variable "diagnostic_log_retention_days" {
  description = "Number of days to retain diagnostic logs"
  type        = number
  default     = 30
  validation {
    condition     = var.diagnostic_log_retention_days >= 0 && var.diagnostic_log_retention_days <= 365
    error_message = "Diagnostic log retention days must be between 0 and 365."
  }
}