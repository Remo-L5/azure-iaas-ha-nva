locals {
  component_name = "f5lb-${var.location}-${var.environment}"
}

module "nva_ha" {
  source = "../../modules/iaas-ha-nva"

  # Basic Configuration
  subscription_id = var.subscription_id
  location        = var.location
  environment     = var.environment
  app_short_name  = "f5lb"

  # VM Configuration
  sku_size = "Standard_D16s_v4" #Standard_Ds_v5 Series is supported. F5 has confirmed (tested) with running ASM/AWAF or APM modules.
  os_type  = "Linux"

  # F5 OS Image
  os_image = {
    publisher = "f5-networks"
    offer     = "f5-big-ip-byol"
    sku       = "f5-big-all-2slot-byol" # 2slot image allows for OS updates without needing to redeploy the VMs.
    plan      = "f5-big-all-2slot-byol"
    version   = "latest"
  }

  managed_identity_resource_ids = toset([azurerm_user_assigned_identity.umi_f5.id])

  capacity_reservation_group_resource_id = azurerm_capacity_reservation_group.crg.id


  # Node Configuration (supports multiple AZs)
  node_configuration = {
    node1 = {
      availability_zone = 1
      sequence_suffix   = "01"
      private_ip_address = {
        untrust_network_interface = "10.0.1.10"
        trust_network_interface   = "10.0.2.10"
      }
    }
    node2 = {
      availability_zone         = 2
      sequence_suffix           = "02"
      public_ip_address_enabled = false
    }
    # Add more nodes as needed
  }
  additional_ip_configurations = {
    node1 = {
      trust_network_interface = {
        failover_ip_config = {
          name                          = "${local.component_name}-01-ipconfig-vip1"
          private_ip_address_allocation = "Static"
          private_ip_address            = "10.0.2.20"
        }
      }
      untrust_network_interface = {
        failover_ip_config = {
          name                          = "${local.component_name}-01-ipconfig-vip-ext"
          private_ip_address_allocation = "Static"
          private_ip_address            = "10.0.1.20"
          create_public_ip_address      = true
          public_ip_address_name        = "pip-${local.component_name}-01-untrust"
        }
      }
    }
  }

  network_interface_tags = {
    trust_network_interface = {
      f5_cloud_failover_label   = "failover",
      f5_cloud_failover_nic_map = "internal"
    }
    untrust_network_interface = {
      f5_cloud_failover_label   = "failover",
      f5_cloud_failover_nic_map = "external"
    }
  }

  # Network Configuration
  trust_private_ip_subnet_resource_id   = "/subscriptions/${var.subscription_id}/resourceGroups/rg-hub-${var.location}/providers/Microsoft.Network/virtualNetworks/vnet-hub-${var.location}/subnets/F5InternalSubnet"
  untrust_private_ip_subnet_resource_id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-hub-${var.location}/providers/Microsoft.Network/virtualNetworks/vnet-hub-${var.location}/subnets/F5ExternalSubnet"
  mgmt_private_ip_subnet_resource_id    = "/subscriptions/${var.subscription_id}/resourceGroups/rg-hub-${var.location}/providers/Microsoft.Network/virtualNetworks/vnet-hub-${var.location}/subnets/F5MgmtSubnet"

  # Security
  keyvault_resource_id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-hub-${var.location}/providers/Microsoft.KeyVault/vaults/your-keyvault"

  # Monitoring and Logging
  log_analytics_workspace_resource_id = var.log_analytics_workspace_resource_id

  # Disable Load Balancing
  enable_load_balancing = false

  # Static IP Configuration
  use_static_ip = var.use_static_ip


  # Optional
  enable_telemetry = false
  tags = {
    Environment = var.environment
    Project     = "Azure Landing Zone"
  }
}

# Create managed identities for the VMs. This allows the VMs to authenticate to Azure services securely without needing to manage credentials.
resource "azurerm_user_assigned_identity" "umi_f5" {
  location            = var.location
  name                = "mi-${local.component_name}"
  resource_group_name = "rg-${local.component_name}"
}

# Create a Storage Account for the VMs to use for tracking failover status and other state information. This is required for the F5 Cloud Failover solution to function properly.
module "avm-res-storage-storageaccount" {
  source                            = "Azure/avm-res-storage-storageaccount/azurerm"
  version                           = "0.6.7"
  account_replication_type          = "ZRS"
  account_tier                      = "Standard"
  account_kind                      = "StorageV2"
  name                              = "stf5lb${var.location}${var.environment}001"
  location                          = var.location
  resource_group_name               = "rg-${local.component_name}"
  min_tls_version                   = "TLS1_2"
  shared_access_key_enabled         = false
  public_network_access_enabled     = false
  infrastructure_encryption_enabled = true

  private_endpoints = {
    blob = {
      name                          = "pe-sto-${local.component_name}"
      subnet_resource_id            = "/subscriptions/${var.subscription_id}/resourceGroups/rg-hub-${var.location}/providers/Microsoft.Network/virtualNetworks/vnet-hub-${var.location}/subnets/F5MgmtSubnet"
      subresource_name              = "blob"
      private_dns_zone_resource_ids = toset([var.blob_private_dns_zone_resource_id])
    }
  }

  containers = {
    failover = {
      name = "f5-load-balancer-failover"
    }
  }


  tags = {
    env                     = var.environment
    role                    = "f5lb"
    module                  = "Azure/avm-res-storage-storageaccount/azurerm"
    version                 = "0.6.7"
    f5_cloud_failover_label = "failover"
  }

  network_rules = {
    default_action             = "Deny"
    virtual_network_subnet_ids = []
    bypass                     = ["AzureServices"]
  }
}

# Custom role required for F5 Cloud Failover Extension to manage failover.
# See examples/active-standby/README.md for the role definition and required permissions.
data "azurerm_role_definition" "failover" {
  name = "Custom F5 Big-IP HA Operator (alz-platform-connectivity)"

}

resource "azurerm_role_assignment" "mi_f5_failover" {
  principal_id       = azurerm_user_assigned_identity.umi_f5.principal_id
  scope              = "/subscriptions/${var.subscription_id}/resourceGroups/rg-${local.component_name}"
  role_definition_id = data.azurerm_role_definition.failover.id
}


# Activity Log Alert for NIC IP configuration changes
resource "azurerm_monitor_activity_log_alert" "f5_failover_alert" {
  name                = "f5lb-appliance-failover-alert"
  location            = "Global"
  resource_group_name = "rg-${local.component_name}"
  scopes              = ["/subscriptions/${var.subscription_id}/resourceGroups/rg-${local.component_name}"]

  description = "Alert when an F5 appliance failover occurs"

  criteria {
    category = "Administrative"
    resource_provider = "Microsoft.Network/networkInterfaces"
    operation_name = "Microsoft.Network/networkInterfaces/write"
    status = "Succeeded"
  }

  action {
    action_group_id = var.failover_alert_action_group_id
  }

  enabled = true
}