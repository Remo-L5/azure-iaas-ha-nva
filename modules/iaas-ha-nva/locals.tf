locals {
  component_name         = "${var.app_short_name}-${var.location}-${var.environment}"
  resource_group_name    = "rg-${local.component_name}"
  vm_name_base_name      = "vm-${local.component_name}"
  ext_slb_fe_config_name = "az-${var.app_short_name}-fe-public-ipconfig"
  ext_slb_be_pool_name   = "bepool-untrust-${var.app_short_name}"
  int_slb_fe_config_name = "az-${var.app_short_name}-fe-trust-ipconfig"
  int_slb_be_pool_name   = "bepool-trust-${var.app_short_name}"
  network_interface_tags = {
    untrust_network_interface = try(var.network_interface_tags.untrust_network_interface, {})
    trust_network_interface   = try(var.network_interface_tags.trust_network_interface, {})
    mgmt_network_interface    = try(var.network_interface_tags.mgmt_network_interface, {})
  }

  default_ip_configurations = {
    for node_key, node in var.node_configuration : node_key => {
      trust_network_interface = {
        default = {
          name                          = "${local.component_name}-${node.sequence_suffix}-ipconfig"
          private_ip_address_allocation = var.use_static_ip ? "Static" : "Dynamic"
          private_ip_address            = node.private_ip_address.trust_network_interface
          private_ip_subnet_resource_id = var.trust_private_ip_subnet_resource_id
          is_primary_ipconfiguration    = true
        }
      }

      untrust_network_interface = {
        default = {
          name                          = "${local.component_name}-${node.sequence_suffix}-ipconfig"
          private_ip_address_allocation = var.use_static_ip ? "Static" : "Dynamic"
          private_ip_address            = node.private_ip_address.untrust_network_interface
          private_ip_subnet_resource_id = var.untrust_private_ip_subnet_resource_id
          create_public_ip_address      = !var.enable_load_balancing && node.public_ip_address_enabled
          public_ip_address_name        = "pip-${local.component_name}-${node.sequence_suffix}-untrust"
          is_primary_ipconfiguration    = true
        }
      }

      mgmt_network_interface = {
        default = {
          name                          = "${local.component_name}-${node.sequence_suffix}-ipconfig"
          private_ip_address_allocation = var.use_static_ip ? "Static" : "Dynamic"
          private_ip_address            = node.private_ip_address.mgmt_network_interface
          private_ip_subnet_resource_id = var.mgmt_private_ip_subnet_resource_id
          is_primary_ipconfiguration    = true
        }
      }
    }
  }

  nic_subnet_mapping = {
    trust_network_interface   = var.trust_private_ip_subnet_resource_id
    untrust_network_interface = var.untrust_private_ip_subnet_resource_id
    mgmt_network_interface    = var.mgmt_private_ip_subnet_resource_id
  }

  ip_configurations = {
    for node_key, node_configs in local.default_ip_configurations : node_key => {
      for nic_key, nic_configs in node_configs :
      nic_key => merge(
        nic_configs,
        {
          for ip_config_key, ip_config in try(var.additional_ip_configurations[node_key][nic_key], {}) :
          ip_config_key => merge(ip_config, {
            private_ip_subnet_resource_id = local.nic_subnet_mapping[nic_key]
            is_primary_ipconfiguration    = false
          })
        }
      )
    }
  }
}

