# Accept marketplace terms and conditions
resource "azapi_resource_action" "accept_terms" {
  type        = "Microsoft.MarketplaceOrdering/agreements@2015-06-01"
  resource_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.MarketplaceOrdering/agreements/${var.os_image.publisher}/${var.os_image.offer}/${var.os_image.plan}"
  method      = "PUT"
  body = {
    properties = {
      accepted = true
    }
  }
  response_export_values = ["*"]
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.3"
  suffix  = [var.app_short_name, var.location, var.environment]

  depends_on = [azapi_resource_action.accept_terms]
}

module "resource_group" {
  source   = "Azure/avm-res-resources-resourcegroup/azurerm"
  version  = "0.2.1"
  location = var.location
  name     = module.naming.resource_group.name_unique
}

module "slb_service_chain" {
  source  = "Azure/avm-res-network-loadbalancer/azurerm"
  version = "0.4.1"
  count   = local.svc_enabled ? 1 : 0

  location            = var.location
  name                = local.svc_enabled ? local.svc_config.load_balancer_name : local.svc_slb_name
  resource_group_name = module.resource_group.name
  enable_telemetry    = var.enable_telemetry
  tags                = var.tags

  frontend_ip_configurations = local.svc_enabled ? {
    service_chain = {
      name                                                        = local.svc_slb_fe_config_name
      create_public_ip_address                                    = false
      gateway_load_balancer_frontend_ip_configuration_resource_id = local.svc_config.gateway_load_balancer_frontend_ip_configuration_id
    }
  } : {}

  backend_address_pools = local.svc_enabled ? {
    service_chain_pool = {
      name = local.svc_slb_be_pool_name
    }
  } : {}

  lb_probes = local.svc_enabled ? {
    service_chain_probe = {
      name                = local.svc_slb_probe_name
      protocol            = local.svc_config.probe_protocol
      port                = local.svc_config.probe_port
      interval_in_seconds = local.svc_config.probe_interval_in_seconds
      number_of_probes    = local.svc_config.probe_number_of_probes
    }
  } : {}

  lb_rules = local.svc_enabled ? {
    ha_ports = {
      name                           = "ha-ports"
      frontend_ip_configuration_name = local.svc_slb_fe_config_name
      backend_address_pool_name      = local.svc_slb_be_pool_name
      probe_object_name              = "service_chain_probe"
      protocol                       = "All"
      frontend_port                  = 0
      backend_port                   = 0
      floating_ip_enabled            = false
      disable_outbound_snat          = true
      idle_timeout_in_minutes        = 4
      load_distribution              = "Default"
    }
  } : {}
}

module "iaas_nva" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "0.19.3"

  for_each = var.node_configuration

  location            = var.location
  resource_group_name = module.resource_group.name
  name                = "${local.vm_name_base_name}-${each.value.sequence_suffix}"
  zone                = each.value.availability_zone

  network_interfaces = merge(
    {
      trust_network_interface = {
        name = "nic-${local.component_name}-${each.value.sequence_suffix}-trust"
        ip_configurations = {
          trust_ip_config = {
            name                          = "${local.component_name}-${each.value.sequence_suffix}-ipconfig"
            private_ip_subnet_resource_id = var.trust_private_ip_subnet_resource_id
            load_balancer_backend_pools = {
              trust_pool = {
                load_balancer_backend_pool_resource_id = module.slb_internal.azurerm_lb_backend_address_pool["bepool_trust"].id
              }
            }
          }
        }
      }
      untrust_network_interface = {
        name = "nic-${local.component_name}-${each.value.sequence_suffix}-untrust"
        ip_configurations = {
          untrust_ip_config = {
            name                          = "${local.component_name}-${each.value.sequence_suffix}-ipconfig"
            private_ip_subnet_resource_id = var.untrust_private_ip_subnet_resource_id
            load_balancer_backend_pools = {
              untrust_pool = {
                load_balancer_backend_pool_resource_id = module.slb_external.azurerm_lb_backend_address_pool["bepool_untrust"].id
              }
            }
          }
        }
      }
      mgmt_network_interface = {
        name = "nic-${local.component_name}-${each.value.sequence_suffix}-mgmt"
        ip_configurations = {
          mgmt_ip_config = {
            name                          = "${local.component_name}-${each.value.sequence_suffix}-ipconfig"
            private_ip_subnet_resource_id = var.mgmt_private_ip_subnet_resource_id
          }
        }
      }
    },
    local.svc_enabled ? {
      service_chain_network_interface = {
        name                  = "nic-${local.component_name}-${each.value.sequence_suffix}-svc"
        ip_forwarding_enabled = true
        ip_configurations = {
          service_chain_ip_config = {
            name                          = "${local.component_name}-${each.value.sequence_suffix}-svc-ipconfig"
            private_ip_subnet_resource_id = local.svc_config.subnet_resource_id
            load_balancer_backend_pools = {
              service_chain_pool = {
                load_balancer_backend_pool_resource_id = module.slb_service_chain[0].azurerm_lb_backend_address_pool["service_chain_pool"].id
              }
            }
          }
        }
      }
    } : {}
  )

  account_credentials = {
    key_vault_configuration = {
      resource_id = var.keyvault_resource_id
      secret_configuration = {
        name = "azureuser-${local.component_name}-${each.value.sequence_suffix}"
      }
    }
    password_authentication_disabled = false
  }
  enable_telemetry           = var.enable_telemetry
  encryption_at_host_enabled = true
  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  os_type  = var.os_type
  sku_size = var.sku_size
  source_image_reference = {
    publisher = var.os_image.publisher
    offer     = var.os_image.offer
    sku       = var.os_image.sku
    version   = var.os_image.version
  }
  tags = var.tags

  diagnostic_settings = {
    vm_diags = {
      name                  = module.naming.monitor_diagnostic_setting.name_unique
      workspace_resource_id = var.log_analytics_workspace_resource_id
      metric_categories     = ["AllMetrics"]
    }
  }

}

module "slb_external" {
  source  = "Azure/avm-res-network-loadbalancer/azurerm"
  version = "0.4.1"

  location            = var.location
  name                = "slb-ext-${local.component_name}"
  resource_group_name = module.resource_group.name
  enable_telemetry    = var.enable_telemetry

  frontend_ip_configurations = {
    frontend_configuration_1 = {
      name = local.ext_slb_fe_config_name
      # Creates a public IP address
      create_public_ip_address        = true
      public_ip_address_resource_name = "pip-slb-ext-${local.component_name}"
      zones                           = ["1", "2", "3"] # Zone-redundant
    }
  }

  backend_address_pools = {
    bepool_untrust = {
      name = local.ext_slb_be_pool_name
    }
  }

  lb_probes = {
    probe_tcp_22 = {
      name                = "probe_tcp_22"
      protocol            = "Tcp"
      port                = 22
      interval_in_seconds = 5
    },
    probe_http_80 = {
      name                = "probe_http_80"
      protocol            = "Http"
      port                = 80
      request_path        = "/health"
      interval_in_seconds = 5
    },
    probe_https_443 = {
      name                = "probe_https_443"
      protocol            = "Https"
      port                = 443
      request_path        = "/health"
      interval_in_seconds = 5
    }
  }

  lb_rules = {
    rule_http = {
      name                           = "rule_http"
      frontend_ip_configuration_name = local.ext_slb_fe_config_name
      backend_address_pool_name      = local.ext_slb_be_pool_name
      probe_object_name              = "probe_http_80"
      protocol                       = "Tcp"
      frontend_port                  = 80
      backend_port                   = 80
      floating_ip_enabled            = false
      idle_timeout_in_minutes        = 4
      load_distribution              = "Default"
    }
    rule_https = {
      name                           = "rule_https"
      frontend_ip_configuration_name = local.ext_slb_fe_config_name
      backend_address_pool_name      = local.ext_slb_be_pool_name
      probe_object_name              = "probe_https_443"
      protocol                       = "Tcp"
      frontend_port                  = 443
      backend_port                   = 443
      floating_ip_enabled            = false
      idle_timeout_in_minutes        = 4
      load_distribution              = "Default"
    }
  }

  diagnostic_settings = {
    default = {
      name                           = "default"
      log_groups                     = ["allLogs"]
      metric_categories              = ["AllMetrics"]
      log_analytics_destination_type = "Dedicated"
      workspace_resource_id          = var.log_analytics_workspace_resource_id
    }
  }

}

module "slb_internal" {
  source  = "Azure/avm-res-network-loadbalancer/azurerm"
  version = "0.4.1"

  location            = var.location
  name                = "slb-int-${local.component_name}"
  resource_group_name = module.resource_group.name
  enable_telemetry    = var.enable_telemetry

  frontend_ip_configurations = {
    frontend_configuration_1 = {
      name                                   = local.int_slb_fe_config_name
      create_public_ip_address               = false
      frontend_private_ip_address_version    = "IPv4"
      frontend_private_ip_subnet_resource_id = var.trust_private_ip_subnet_resource_id
      zones                                  = ["1", "2", "3"] # Zone-redundant
    }
  }

  backend_address_pools = {
    bepool_trust = {
      name = local.int_slb_be_pool_name
    }
  }

  lb_probes = {
    probe_tcp_22 = {
      name                = "probe_tcp_22"
      protocol            = "Tcp"
      port                = 22
      interval_in_seconds = 5
    },
    probe_http_80 = {
      name                = "probe_http_80"
      protocol            = "Http"
      port                = 80
      request_path        = "/health"
      interval_in_seconds = 5
    },
    probe_https_443 = {
      name                = "probe_https_443"
      protocol            = "Https"
      port                = 443
      request_path        = "/health"
      interval_in_seconds = 5
    }
  }

  lb_rules = {
    rule_http = {
      name                           = "rule_http"
      frontend_ip_configuration_name = local.int_slb_fe_config_name
      backend_address_pool_name      = local.int_slb_be_pool_name
      probe_object_name              = "probe_http_80"
      protocol                       = "Tcp"
      frontend_port                  = 80
      backend_port                   = 80
      floating_ip_enabled            = false
      idle_timeout_in_minutes        = 4
      load_distribution              = "Default"
    }
    rule_https = {
      name                           = "rule_https"
      frontend_ip_configuration_name = local.int_slb_fe_config_name
      backend_address_pool_name      = local.int_slb_be_pool_name
      probe_object_name              = "probe_https_443"
      protocol                       = "Tcp"
      frontend_port                  = 443
      backend_port                   = 443
      floating_ip_enabled            = false
      idle_timeout_in_minutes        = 4
      load_distribution              = "Default"
    }
  }

  diagnostic_settings = {
    default = {
      name                           = "default"
      log_groups                     = ["allLogs"]
      metric_categories              = ["AllMetrics"]
      log_analytics_destination_type = "Dedicated"
      workspace_resource_id          = var.log_analytics_workspace_resource_id
    }
  }

}

# Data Collection Rule for VM Performance Monitoring
resource "azurerm_monitor_data_collection_rule" "vm_performance" {
  name                = "dcr-vmperf-${local.component_name}"
  resource_group_name = module.resource_group.name
  location            = var.location
  tags                = var.tags

  destinations {
    log_analytics {
      workspace_resource_id = var.log_analytics_workspace_resource_id
      name                  = "log-analytics-dest"
    }
  }

  data_flow {
    streams      = ["Microsoft-Perf", "Microsoft-InsightsMetrics"]
    destinations = ["log-analytics-dest"]
  }

  data_sources {
    performance_counter {
      streams                       = ["Microsoft-Perf", "Microsoft-InsightsMetrics"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\Processor Information(_Total)\\% Processor Time",
        "\\Processor Information(_Total)\\% Privileged Time",
        "\\Processor Information(_Total)\\% User Time",
        "\\Processor Information(_Total)\\Processor Frequency",
        "\\System\\Processes",
        "\\Process(_Total)\\Thread Count",
        "\\Process(_Total)\\Handle Count",
        "\\System\\System Up Time",
        "\\System\\Context Switches/sec",
        "\\System\\Processor Queue Length",
        "\\Memory\\% Committed Bytes In Use",
        "\\Memory\\Available Bytes",
        "\\Memory\\Committed Bytes",
        "\\Memory\\Cache Bytes",
        "\\Memory\\Pool Paged Bytes",
        "\\Memory\\Pool Nonpaged Bytes",
        "\\Memory\\Pages/sec",
        "\\Memory\\Page Faults/sec",
        "\\Memory\\Page Reads/sec",
        "\\Memory\\Page Writes/sec",
        "\\LogicalDisk(_Total)\\% Disk Time",
        "\\LogicalDisk(_Total)\\% Disk Read Time",
        "\\LogicalDisk(_Total)\\% Disk Write Time",
        "\\LogicalDisk(_Total)\\% Idle Time",
        "\\LogicalDisk(_Total)\\Disk Bytes/sec",
        "\\LogicalDisk(_Total)\\Disk Read Bytes/sec",
        "\\LogicalDisk(_Total)\\Disk Write Bytes/sec",
        "\\LogicalDisk(_Total)\\Disk Transfers/sec",
        "\\LogicalDisk(_Total)\\Disk Reads/sec",
        "\\LogicalDisk(_Total)\\Disk Writes/sec",
        "\\LogicalDisk(_Total)\\Avg. Disk sec/Transfer",
        "\\LogicalDisk(_Total)\\Avg. Disk sec/Read",
        "\\LogicalDisk(_Total)\\Avg. Disk sec/Write",
        "\\LogicalDisk(_Total)\\Avg. Disk Queue Length",
        "\\LogicalDisk(_Total)\\Avg. Disk Read Queue Length",
        "\\LogicalDisk(_Total)\\Avg. Disk Write Queue Length",
        "\\LogicalDisk(_Total)\\% Free Space",
        "\\LogicalDisk(_Total)\\Free Megabytes",
        "\\Network Interface(*)\\Bytes Total/sec",
        "\\Network Interface(*)\\Bytes Sent/sec",
        "\\Network Interface(*)\\Bytes Received/sec",
        "\\Network Interface(*)\\Packets/sec",
        "\\Network Interface(*)\\Packets Sent/sec",
        "\\Network Interface(*)\\Packets Received/sec",
        "\\Network Interface(*)\\Packets Outbound Errors",
        "\\Network Interface(*)\\Packets Received Errors"
      ]
      name = "perfCounterDataSource60"
    }
  }
}

# Data Collection Rule Association for Virtual Machines
resource "azurerm_monitor_data_collection_rule_association" "vm_dcr_association" {
  for_each = var.node_configuration

  name                    = "dcra-vm-${each.value.sequence_suffix}"
  target_resource_id      = module.iaas_nva[each.key].resource_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vm_performance.id
}
