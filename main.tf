module "nva_ha" {
  source = "./modules/iaas-ha-nva"

  # Basic Configuration
  subscription_id = var.subscription_id
  location        = var.location
  environment     = var.environment
  app_short_name  = "panfw"

  # VM Configuration
  sku_size = "Standard_D16s_v5"
  os_type  = "Linux"

  # Palo Alto OS Image
  os_image = {
    publisher = "paloaltonetworks"
    offer     = "vmseries-flex"
    plan      = "byol"
    sku       = "byol"
    version   = "latest"
  }

  # Node Configuration (supports multiple AZs)
  node_configuration = {
    node1 = {
      availability_zone = 1
      sequence_suffix   = "01"
    }
    node2 = {
      availability_zone = 2
      sequence_suffix   = "02"
    }
    # Add more nodes as needed
  }

  # Network Configuration
  trust_private_ip_subnet_resource_id   = "/subscriptions/${var.subscription_id}/resourceGroups/rg-hub-${var.location}/providers/Microsoft.Network/virtualNetworks/vnet-hub-${var.location}/subnets/trust-subnet"
  untrust_private_ip_subnet_resource_id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-hub-${var.location}/providers/Microsoft.Network/virtualNetworks/vnet-hub-${var.location}/subnets/untrust-subnet"

  # Security
  keyvault_resource_id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-hub-core-${var.location}/providers/Microsoft.KeyVault/vaults/your-keyvault"

  # Monitoring and Logging
  log_analytics_workspace_resource_id = var.log_analytics_workspace_resource_id
  enable_diagnostic_settings          = true
  enable_data_collection_rules        = true

  # Optional
  enable_telemetry = false
  tags = {
    Environment = var.environment
    Project     = "Azure Landing Zone"
  }
}