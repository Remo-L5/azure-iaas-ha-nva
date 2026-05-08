module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
  suffix  = [var.app_short_name, var.location, var.environment]
}

module "resource_group" {
  source   = "Azure/avm-res-resources-resourcegroup/azurerm"
  version  = "0.2.1"
  location = var.location
  name     = module.naming.resource_group.name
}

module "iaas_nva" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "0.20.0"

  for_each = var.node_configuration

  location                               = var.location
  resource_group_name                    = module.resource_group.name
  name                                   = "${local.vm_name_base_name}-${each.value.sequence_suffix}"
  zone                                   = each.value.availability_zone
  capacity_reservation_group_resource_id = var.capacity_reservation_group_resource_id

  network_interfaces = {
    trust_network_interface = {
      name                  = "nic-${local.component_name}-${each.value.sequence_suffix}-trust"
      tags                  = local.network_interface_tags.trust_network_interface
      ip_forwarding_enabled = true
      ip_configurations     = local.ip_configurations[each.key].trust_network_interface
    }
    untrust_network_interface = {
      name                  = "nic-${local.component_name}-${each.value.sequence_suffix}-untrust"
      tags                  = local.network_interface_tags.untrust_network_interface
      ip_forwarding_enabled = true
      ip_configurations     = local.ip_configurations[each.key].untrust_network_interface
    }
    mgmt_network_interface = {
      name              = "nic-${local.component_name}-${each.value.sequence_suffix}-mgmt"
      tags              = local.network_interface_tags.mgmt_network_interface
      ip_configurations = local.ip_configurations[each.key].mgmt_network_interface
    }
  }

  public_ip_configuration_details = {
    ddos_protection_mode = "Enabled"
  }

  managed_identities = {
    system_assigned            = var.enable_system_identity
    user_assigned_resource_ids = var.managed_identity_resource_ids
  }

  account_credentials = {
    key_vault_configuration = {
      resource_id = var.keyvault_resource_id
      secret_configuration = {
        name = "${local.component_name}-${each.value.sequence_suffix}-password"
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
  plan = {
    name      = var.os_image.plan
    product   = var.os_image.offer
    publisher = var.os_image.publisher
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
  version = "0.5.0"
  count   = var.enable_load_balancing ? 1 : 0


  location            = var.location
  name                = "slb-ext-${local.component_name}"
  resource_group_name = module.resource_group.name
  enable_telemetry    = var.enable_telemetry

  public_ip_address_configuration = {
    allocation_method                = "Static"
    ddos_protection_mode             = "Enabled"
    ddos_protection_plan_resource_id = null
    sku                              = "Standard"
    sku_tier                         = "Regional"
  }

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

  backend_address_pool_network_interfaces = {
    for key, vm_config in var.node_configuration : key => {
      backend_address_pool_object_name = "bepool_untrust"
      ip_configuration_name            = "${local.component_name}-${vm_config.sequence_suffix}-ipconfig"
      network_interface_resource_id    = module.iaas_nva[key].network_interfaces["untrust_network_interface"].id
    }
  }

  lb_probes = {
    probe_tcp_22 = {
      name                = "probe_tcp_22"
      protocol            = "Tcp"
      port                = 22
      interval_in_seconds = 5
    },
    probe_tcp_80 = {
      name                = "probe_tcp_80"
      protocol            = "Tcp"
      port                = 80
      interval_in_seconds = 5
    },
    probe_tcp_443 = {
      name                = "probe_tcp_443"
      protocol            = "Tcp"
      port                = 443
      interval_in_seconds = 5
    }
  }

  lb_rules = {
    rule_http = {
      name                              = "rule_http"
      frontend_ip_configuration_name    = local.ext_slb_fe_config_name
      backend_address_pool_object_names = ["bepool_untrust"]
      probe_object_name                 = "probe_tcp_80"
      protocol                          = "Tcp"
      frontend_port                     = 80
      backend_port                      = 80
      floating_ip_enabled               = false
      idle_timeout_in_minutes           = 4
      load_distribution                 = "Default"
    }
    rule_https = {
      name                              = "rule_https"
      frontend_ip_configuration_name    = local.ext_slb_fe_config_name
      backend_address_pool_object_names = ["bepool_untrust"]
      probe_object_name                 = "probe_tcp_443"
      protocol                          = "Tcp"
      frontend_port                     = 443
      backend_port                      = 443
      floating_ip_enabled               = false
      idle_timeout_in_minutes           = 4
      load_distribution                 = "Default"
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
  version = "0.5.0"
  count   = var.enable_load_balancing ? 1 : 0


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

  backend_address_pool_network_interfaces = {
    for key, vm_config in var.node_configuration : key => {
      backend_address_pool_object_name = "bepool_trust"
      ip_configuration_name            = "${local.component_name}-${vm_config.sequence_suffix}-ipconfig"
      network_interface_resource_id    = module.iaas_nva[key].network_interfaces["trust_network_interface"].id
    }
  }

  lb_probes = {
    probe_tcp_22 = {
      name                = "probe_tcp_22"
      protocol            = "Tcp"
      port                = 22
      interval_in_seconds = 5
    },
    probe_tcp_80 = {
      name                = "probe_tcp_80"
      protocol            = "Tcp"
      port                = 80
      interval_in_seconds = 5
    },
    probe_tcp_443 = {
      name                = "probe_tcp_443"
      protocol            = "Tcp"
      port                = 443
      interval_in_seconds = 5
    }
  }

  lb_rules = {
    rule_all = {
      name                              = "rule_all"
      frontend_ip_configuration_name    = local.int_slb_fe_config_name
      backend_address_pool_object_names = ["bepool_trust"]
      probe_object_name                 = "probe_tcp_80"
      protocol                          = "All"
      frontend_port                     = 0
      backend_port                      = 0
      enable_floating_ip                = true
      idle_timeout_in_minutes           = 4
      load_distribution                 = "SourceIPProtocol"
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

# Data Collection Rule for VM Performance Monitoring (Linux)
resource "azurerm_monitor_data_collection_rule" "vm_performance" {
  count               = var.os_type == "Linux" ? 1 : 0
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
        # CPU metrics
        "Processor(*)\\% Processor Time",
        "Processor(*)\\% Idle Time",
        "Processor(*)\\% User Time",
        "Processor(*)\\% Nice Time",
        "Processor(*)\\% Privileged Time",
        "Processor(*)\\% IO Wait Time",
        "Processor(*)\\% Interrupt Time",
        # Memory metrics
        "Memory(*)\\Available MBytes Memory",
        "Memory(*)\\% Available Memory",
        "Memory(*)\\Used Memory MBytes",
        "Memory(*)\\% Used Memory",
        "Memory(*)\\Pages/sec",
        "Memory(*)\\Page Reads/sec",
        "Memory(*)\\Page Writes/sec",
        "Memory(*)\\Available MBytes Swap",
        "Memory(*)\\% Available Swap Space",
        "Memory(*)\\Used MBytes Swap Space",
        "Memory(*)\\% Used Swap Space",
        # Disk metrics
        "Logical Disk(*)\\% Free Inodes",
        "Logical Disk(*)\\% Used Inodes",
        "Logical Disk(*)\\Free Megabytes",
        "Logical Disk(*)\\% Free Space",
        "Logical Disk(*)\\% Used Space",
        "Logical Disk(*)\\Logical Disk Bytes/sec",
        "Logical Disk(*)\\Disk Read Bytes/sec",
        "Logical Disk(*)\\Disk Write Bytes/sec",
        "Logical Disk(*)\\Disk Transfers/sec",
        "Logical Disk(*)\\Disk Reads/sec",
        "Logical Disk(*)\\Disk Writes/sec",
        # Network metrics
        "Network(*)\\Total Bytes Transmitted",
        "Network(*)\\Total Bytes Received",
        "Network(*)\\Total Bytes",
        "Network(*)\\Total Packets Transmitted",
        "Network(*)\\Total Packets Received",
        "Network(*)\\Total Rx Errors",
        "Network(*)\\Total Tx Errors",
        "Network(*)\\Total Collisions"
      ]
      name = "perfCounterDataSource60"
    }
  }
}

# Data Collection Rule for VM Performance Monitoring (Windows)
resource "azurerm_monitor_data_collection_rule" "vm_performance_windows" {
  count               = var.os_type == "Windows" ? 1 : 0
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
  data_collection_rule_id = var.os_type == "Linux" ? azurerm_monitor_data_collection_rule.vm_performance[0].id : azurerm_monitor_data_collection_rule.vm_performance_windows[0].id
}
