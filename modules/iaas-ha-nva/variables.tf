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

  validation {
    condition     = contains(["Linux", "Windows"], var.os_type)
    error_message = "os_type must be either 'Linux' or 'Windows'."
  }
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
    public_ip_address_enabled = optional(bool, false)
    private_ip_address = optional(object({
      trust_network_interface   = optional(string, null)
      untrust_network_interface = optional(string, null)
      mgmt_network_interface    = optional(string, null)
    }), {})
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
  description = "The resource ID of the management private IP subnet"
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

variable "enable_system_identity" {
  description = "enable the vm system identity"
  type        = bool
  default     = false
}

variable "enable_load_balancing" {
  description = "Enable load balancing for the virtual machines"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_resource_id" {
  description = "The resource ID of the Log Analytics workspace for diagnostic logs and monitoring"
  type        = string
  default     = null
}

variable "use_static_ip" {
  description = "Whether to use static IP addresses for the virtual machines"
  type        = bool
  default     = true
}

variable "managed_identity_resource_ids" {
  type        = set(string)
  default     = []
  description = "Managed identities to apply to the VMs."
}

variable "network_interface_tags" {
  type = object({
    untrust_network_interface = optional(map(string), {})
    trust_network_interface   = optional(map(string), {})
    mgmt_network_interface    = optional(map(string), {})
  })
  default = {}

}

variable "additional_ip_configurations" {
  type = map(map(map(object({
    name                          = string
    private_ip_address_allocation = optional(string, "Dynamic")
    private_ip_address            = optional(string)
    create_public_ip_address      = optional(bool, false)
    public_ip_address_name        = optional(string)
  }))))
  default     = {}
  description = "Additional IP configurations for network interfaces"
}

variable "capacity_reservation_group_resource_id" {
  type        = string
  default     = null
  description = "(Optional) Specifies the Azure Resource ID of the Capacity Reservation Group with the Virtual Machine should be allocated to. Cannot be used with availability_set_id or proximity_placement_group_id"
}