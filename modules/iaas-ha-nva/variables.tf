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

variable "service_chain_configuration" {
  description = <<DESC
Optional configuration for integrating with a Gateway Load Balancer by provisioning an additional service chain interface and Standard Load Balancer.
Provide `null` to disable the integration.
DESC
  type = object({
    subnet_resource_id                                 = string
    gateway_load_balancer_frontend_ip_configuration_id = string
    probe_protocol                                     = optional(string)
    probe_port                                         = optional(number)
    probe_interval_in_seconds                          = optional(number)
    probe_number_of_probes                             = optional(number)
    load_balancer_name                                 = optional(string)
  })
  default  = null
  nullable = true

  validation {
    condition     = var.service_chain_configuration == null || contains(["Tcp", "Http", "Https"], coalesce(try(var.service_chain_configuration.probe_protocol, null), "Tcp"))
    error_message = "When service_chain_configuration is provided, probe_protocol must be one of Tcp, Http, or Https."
  }

  validation {
    condition     = var.service_chain_configuration == null || ((coalesce(try(var.service_chain_configuration.probe_port, null), 80) >= 1) && (coalesce(try(var.service_chain_configuration.probe_port, null), 80) <= 65535))
    error_message = "When service_chain_configuration is provided, probe_port must be between 1 and 65535."
  }

  validation {
    condition     = var.service_chain_configuration == null || ((coalesce(try(var.service_chain_configuration.probe_interval_in_seconds, null), 5) >= 5) && (coalesce(try(var.service_chain_configuration.probe_interval_in_seconds, null), 5) <= 60))
    error_message = "When service_chain_configuration is provided, probe_interval_in_seconds must be between 5 and 60 seconds."
  }

  validation {
    condition     = var.service_chain_configuration == null || ((coalesce(try(var.service_chain_configuration.probe_number_of_probes, null), 2) >= 1) && (coalesce(try(var.service_chain_configuration.probe_number_of_probes, null), 2) <= 20))
    error_message = "When service_chain_configuration is provided, probe_number_of_probes must be between 1 and 20."
  }
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