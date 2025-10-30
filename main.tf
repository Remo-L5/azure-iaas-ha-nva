module "nva_ha" {
  source = "./modules/iaas-ha-nva"

  # Basic Configuration
  subscription_id = var.subscription_id
  location        = var.location
  environment     = var.environment
  app_short_name  = "panfw"

  # VM Configuration
  sku_size = "Standard_D16s_v4"
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
  mgmt_private_ip_subnet_resource_id    = "/subscriptions/${var.subscription_id}/resourceGroups/rg-hub-${var.location}/providers/Microsoft.Network/virtualNetworks/vnet-hub-${var.location}/subnets/mgmt-subnet"

  # Security
  keyvault_resource_id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-hub-core-${var.location}/providers/Microsoft.KeyVault/vaults/your-keyvault"

  # Monitoring and Logging
  log_analytics_workspace_resource_id = var.log_analytics_workspace_resource_id

  # Optional
  service_chain_configuration = {
    subnet_resource_id                                 = "/subscriptions/${var.subscription_id}/resourceGroups/rg-hub-${var.location}/providers/Microsoft.Network/virtualNetworks/vnet-hub-${var.location}/subnets/service-chain"
    gateway_load_balancer_frontend_ip_configuration_id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-hub-${var.location}/providers/Microsoft.Network/loadBalancers/gwlb-${var.location}/frontendIPConfigurations/gwlb-frontend"
    probe_port                                         = 443
    frontend_port                                      = 0
    backend_port                                       = 0
  }
  enable_telemetry = false
  tags = {
    Environment = var.environment
    Project     = "Azure Landing Zone"
  }
}