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

variable "log_analytics_workspace_resource_id" {
  description = "The resource ID of the Log Analytics workspace for diagnostic logs and monitoring"
  type        = string
  default     = null
}

variable "use_static_ip" {
  description = "Whether to use static IP addresses for the VMs"
  type        = bool
  default     = true

}

variable "failover_alert_action_group_id" {
  description = "The resource ID of the Azure Monitor Action Group to notify when an F5 failover occurs"
  type        = string
}

variable "blob_private_dns_zone_resource_id" {
  description = "The resource ID of the private DNS zone for blob storage (privatelink.blob.core.windows.net), used for the F5 failover storage account private endpoint"
  type        = string
}
