locals {
  component_name         = "${var.app_short_name}-${var.location}-${var.environment}"
  resource_group_name    = "rg-${local.component_name}"
  vm_name_base_name      = "vm-${local.component_name}"
  ext_slb_fe_config_name = "az-${var.app_short_name}-fe-public-ipconfig"
  ext_slb_be_pool_name   = "bepool-untrust-${var.app_short_name}"
  int_slb_fe_config_name = "az-${var.app_short_name}-fe-trust-ipconfig"
  int_slb_be_pool_name   = "bepool-trust-${var.app_short_name}"
}
