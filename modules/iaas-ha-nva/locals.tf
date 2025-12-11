locals {
  component_name         = "${var.app_short_name}-${var.location}-${var.environment}"
  resource_group_name    = "rg-${local.component_name}"
  vm_name_base_name      = "vm-${local.component_name}"
  ext_slb_fe_config_name = "az-${var.app_short_name}-fe-public-ipconfig"
  ext_slb_be_pool_name   = "bepool-untrust-${var.app_short_name}"
  int_slb_fe_config_name = "az-${var.app_short_name}-fe-trust-ipconfig"
  int_slb_be_pool_name   = "bepool-trust-${var.app_short_name}"
  svc_slb_name           = "slb-svc-${var.app_short_name}"
  svc_slb_fe_config_name = "az-${var.app_short_name}-fe-svc"
  svc_slb_be_pool_name   = "bepool-svc-${var.app_short_name}"
  svc_slb_probe_name     = "probe-svc-${var.app_short_name}"
  svc_slb_public_ip_name = "pip-slb-svc-${local.component_name}"
  # Gateway Load Balancer naming
  gwlb_name           = "gwlb-${var.app_short_name}"
  gwlb_fe_config_name = "az-${var.app_short_name}-fe-gwlb"
  gwlb_be_pool_name   = "bepool-gwlb-${var.app_short_name}"
  gwlb_probe_name     = "probe-gwlb-${var.app_short_name}"
  svc_enabled         = var.service_chain_configuration != null
  svc_config = local.svc_enabled ? {
    subnet_resource_id              = var.service_chain_configuration.subnet_resource_id
    probe_protocol                  = coalesce(try(var.service_chain_configuration.probe_protocol, null), "Tcp")
    probe_port                      = coalesce(try(var.service_chain_configuration.probe_port, null), 443)
    probe_interval_in_seconds       = coalesce(try(var.service_chain_configuration.probe_interval_in_seconds, null), 5)
    probe_number_of_probes          = coalesce(try(var.service_chain_configuration.probe_number_of_probes, null), 2)
    load_balancer_name              = coalesce(try(var.service_chain_configuration.load_balancer_name, null), local.svc_slb_name)
    create_public_ip_address        = coalesce(try(var.service_chain_configuration.create_public_ip_address, null), true)
    public_ip_address_resource_name = coalesce(try(var.service_chain_configuration.public_ip_address_resource_name, null), local.svc_slb_public_ip_name)
    frontend_port                   = coalesce(try(var.service_chain_configuration.frontend_port, null), 0)
    backend_port                    = coalesce(try(var.service_chain_configuration.backend_port, null), 0)
    # Gateway Load Balancer settings
    gateway_load_balancer_name = coalesce(try(var.service_chain_configuration.gateway_load_balancer_name, null), local.gwlb_name)
    internal_tunnel_port       = coalesce(try(var.service_chain_configuration.internal_tunnel_port, null), 10800)
    external_tunnel_port       = coalesce(try(var.service_chain_configuration.external_tunnel_port, null), 10801)
    internal_tunnel_identifier = coalesce(try(var.service_chain_configuration.internal_tunnel_identifier, null), 800)
    external_tunnel_identifier = coalesce(try(var.service_chain_configuration.external_tunnel_identifier, null), 801)
  } : null
}
