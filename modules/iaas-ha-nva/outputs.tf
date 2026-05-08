output "untrust_network_interfaces" {
  description = "Map of untrust network interfaces for the NVA virtual machines"
  value = {
    for key, vm in module.iaas_nva : key => {
      id                 = vm.network_interfaces["untrust_network_interface"].id
      private_ip_address = vm.network_interfaces["untrust_network_interface"].private_ip_address
    }
  }
}

output "trust_network_interfaces" {
  description = "Map of trust network interfaces for the NVA virtual machines"
  value = {
    for key, vm in module.iaas_nva : key => {
      id                 = vm.network_interfaces["trust_network_interface"].id
      private_ip_address = vm.network_interfaces["trust_network_interface"].private_ip_address
    }
  }
}

output "external_load_balancer" {
  description = "External load balancer information"
  value = var.enable_load_balancing ? {
    id   = module.slb_external[0].resource_id
    name = module.slb_external[0].name
  } : null
}

output "internal_load_balancer" {
  description = "Internal load balancer information"
  value = var.enable_load_balancing ? {
    id   = module.slb_internal[0].resource_id
    name = module.slb_internal[0].name
  } : null
}