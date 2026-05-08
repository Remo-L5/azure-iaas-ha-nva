# Azure IaaS High Availability Network Virtual Appliance (NVA)

A Terraform module for deploying highly available Network Virtual Appliances (NVAs) in Azure with optional dual load balancers for comprehensive traffic management. The module is vendor-agnostic and has been validated with images such as Palo Alto VM-Series and F5 Big-IP.

## Overview

This module abstracts the complexity of deploying a high-availability NVA solution in Azure by providing a simple interface that accepts a `node_configuration` map to deploy VMs across multiple availability zones. The architecture is designed to scale horizontally and can be extended in the future as needed.

## Architecture

The module deploys the following components:

### Core Infrastructure
- **Virtual Machines**: NVA appliances deployed across availability zones
- **Network Interfaces**: Each VM has three NICs (trust, untrust, and management subnets)
- **External Load Balancer** (optional): Public-facing load balancer with public IP
- **Internal Load Balancer** (optional): Private load balancer for spoke network routing
- **Resource Group**: Managed with consistent naming conventions
- **Diagnostics**: VM and load balancer diagnostic settings, plus a Data Collection Rule for OS performance metrics (Linux or Windows)

### Network Flow Design

```
Internet Traffic Flow:
Internet → External LB (Public IP) → Untrust NICs → NVA → Trust NICs → Internal Network

Spoke Network Traffic Flow:
Spoke Networks → Internal LB (Next-hop) → Trust NICs → NVA → Untrust NICs → Internet
```

### Load Balancer Configuration

Load balancers are deployed only when `enable_load_balancing = true` (the default). When disabled, the module deploys VMs only and is suitable for vendor-managed failover patterns (e.g., F5 Cloud Failover).

#### External Load Balancer (`slb_external`)
- **Frontend**: Public IP address with zone redundancy
- **Backend Pool**: Connected to all VM untrust network interfaces
- **Purpose**: Handles inbound traffic from the internet
- **Health Probes**: TCP (22), HTTP (80), HTTPS (443)
- **Load Balancing Rules**: HTTP and HTTPS traffic distribution

#### Internal Load Balancer (`slb_internal`)
- **Frontend**: Private IP in the trust subnet
- **Backend Pool**: Connected to all VM trust network interfaces  
- **Purpose**: Serves as next-hop for spoke networks routing to internet
- **Health Probes**: TCP (22), HTTP (80), HTTPS (443)
- **Load Balancing Rules**: HA Ports rule for all protocols/ports

## Features

- ✅ **High Availability**: Zone-redundant deployment across multiple availability zones
- ✅ **Scalability**: Easy horizontal scaling by updating the node configuration
- ✅ **Optional Dual Load Balancers**: Separate external and internal load balancers for optimal traffic flow
- ✅ **Automated Backend Pool Management**: Dynamic association of VMs to load balancer backend pools
- ✅ **Consistent Naming**: Azure naming module for standardized resource names
- ✅ **Security**: Key Vault integration for VM credentials, encryption at host enabled
- ✅ **Monitoring**: Built-in health probes for load balancers
- ✅ **Comprehensive Logging**: Log Analytics integration with diagnostic settings
- ✅ **Performance Monitoring**: OS-aware Data Collection Rules (Linux and Windows)
- ✅ **Centralized Monitoring**: Optional Log Analytics workspace integration

## Usage

### Basic Example

```hcl
module "nva_ha" {
  source = "./modules/iaas-ha-nva"

  # Basic Configuration
  subscription_id = "your-subscription-id"
  location        = "eastus2"
  environment     = "prod"
  app_short_name  = "nva"

  # VM Configuration
  sku_size = "Standard_D3_v2"
  os_type  = "Linux"

  # NVA OS Image (example: Palo Alto VM-Series)
  os_image = {
    publisher = "paloaltonetworks"
    offer     = "vmseries-flex"
    sku       = "byol"
    plan      = "byol"
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
  }

  # Network Configuration
  trust_private_ip_subnet_resource_id   = "/subscriptions/.../subnets/trust-subnet"
  untrust_private_ip_subnet_resource_id = "/subscriptions/.../subnets/untrust-subnet"
  mgmt_private_ip_subnet_resource_id    = "/subscriptions/.../subnets/mgmt-subnet"

  # Security
  keyvault_resource_id = "/subscriptions/.../vaults/your-keyvault"

  # Monitoring and Logging (Optional)
  log_analytics_workspace_resource_id = "/subscriptions/.../workspaces/your-log-analytics"

  # Optional
  enable_telemetry = false
  tags = {
    Environment = "Production"
    Project     = "Network Security"
  }
}
```

### Advanced Multi-Zone Example

```hcl
# Deploy across 3 availability zones with 6 firewalls
node_configuration = {
  zone1_primary = {
    availability_zone = 1
    sequence_suffix   = "01"
  }
  zone1_secondary = {
    availability_zone = 1
    sequence_suffix   = "02"
  }
  zone2_primary = {
    availability_zone = 2
    sequence_suffix   = "03"
  }
  zone2_secondary = {
    availability_zone = 2
    sequence_suffix   = "04"
  }
  zone3_primary = {
    availability_zone = 3
    sequence_suffix   = "05"
  }
  zone3_secondary = {
    availability_zone = 3
    sequence_suffix   = "06"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| subscription_id | The ID of the Azure subscription | `string` | n/a | yes |
| location | The location of the resources | `string` | n/a | yes |
| environment | The environment of the deployment (e.g., dev, prod) | `string` | n/a | yes |
| app_short_name | The name of the component | `string` | n/a | yes |
| node_configuration | Map of node configurations (AZ, suffix, optional public IP, optional static IPs per NIC) | `map(object)` | n/a | yes |
| trust_private_ip_subnet_resource_id | Resource ID of the trust subnet | `string` | n/a | yes |
| untrust_private_ip_subnet_resource_id | Resource ID of the untrust subnet | `string` | n/a | yes |
| mgmt_private_ip_subnet_resource_id | Resource ID of the management subnet | `string` | n/a | yes |
| keyvault_resource_id | Resource ID of the Key Vault for VM admin credentials | `string` | n/a | yes |
| os_image | OS image configuration (publisher, offer, sku, plan, version) | `object` | n/a | yes |
| sku_size | The SKU size of the virtual machine | `string` | `"Standard_DS1_v2"` | no |
| os_type | The OS type of the virtual machine (`Linux` or `Windows`) | `string` | `"Linux"` | no |
| enable_telemetry | Enable telemetry for the AVM modules | `bool` | `false` | no |
| enable_system_identity | Enable the VM system-assigned managed identity | `bool` | `false` | no |
| enable_load_balancing | Deploy external and internal Standard Load Balancers | `bool` | `true` | no |
| use_static_ip | Use static private IP allocation for VM NICs | `bool` | `true` | no |
| log_analytics_workspace_resource_id | Resource ID of Log Analytics workspace for diagnostics | `string` | `null` | no |
| managed_identity_resource_ids | User-assigned managed identity resource IDs to attach to the VMs | `set(string)` | `[]` | no |
| network_interface_tags | Per-NIC tags (`trust_network_interface`, `untrust_network_interface`, `mgmt_network_interface`) | `object` | `{}` | no |
| additional_ip_configurations | Additional IP configurations per node and NIC (e.g., floating/failover IPs) | `map(map(map(object)))` | `{}` | no |
| capacity_reservation_group_resource_id | Resource ID of a Capacity Reservation Group to allocate VMs into | `string` | `null` | no |
| tags | A map of tags to assign to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| untrust_network_interfaces | Map of untrust network interfaces for the NVA virtual machines |
| trust_network_interfaces | Map of trust network interfaces for the NVA virtual machines |
| external_load_balancer | External load balancer information (`null` when `enable_load_balancing = false`) |
| internal_load_balancer | Internal load balancer information (`null` when `enable_load_balancing = false`) |

## Prerequisites

1. **Azure Subscription**: Active Azure subscription with appropriate permissions
2. **Network Infrastructure**: Pre-existing VNet with trust, untrust, and management subnets
3. **Key Vault**: Azure Key Vault for storing VM admin credentials
4. **Log Analytics Workspace**: (Optional) For centralized logging and monitoring
5. **Terraform**: Version 1.12.0 or higher
6. **AzureRM Provider**: Version 4.0 or higher
7. **Marketplace Terms**: Accept marketplace terms for your chosen NVA image (see [examples](../../examples/) for vendor-specific commands)

## NVA Vendor Notes

This module is vendor-agnostic. The behavior depends on the `os_image`, `os_type`, and `enable_load_balancing` you provide:

- **Palo Alto VM-Series**: Use `enable_load_balancing = true` for an active-active topology behind Standard Load Balancers. See [examples/active-active](../../examples/active-active/).
- **F5 Big-IP**: Use `enable_load_balancing = false` and rely on F5 Cloud Failover Extension for active-standby IP failover. See [examples/active-standby](../../examples/active-standby/).
- **Other NVAs**: Provide the appropriate publisher/offer/sku/plan in `os_image` and accept the marketplace terms manually.

Health probes default to TCP 22 / 80 / 443, which suit most NVA management and data-plane endpoints.

## Best Practices

1. **Subnet Planning**: Use separate subnets for trust, untrust, and management traffic
2. **Routing**: Configure User Defined Routes (UDRs) to direct spoke traffic through the internal load balancer (or floating VIP for vendor failover)
3. **Security**: Use Azure Key Vault for credential management; enable system or user-assigned managed identities
4. **Monitoring**: Enable Azure Monitor and configure alerts for load balancer / NIC health
5. **Log Analytics**: Connect to a Log Analytics workspace for centralized monitoring
6. **Performance Monitoring**: The module deploys an OS-appropriate Data Collection Rule automatically
7. **Updates**: Regularly update to the latest NVA image versions and Terraform provider versions

## Contributing

Please read our contributing guidelines and submit pull requests to the main branch.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and questions:
1. Check the [Issues](../../issues) section
2. Review your NVA vendor's documentation (Palo Alto, F5, etc.)
3. Consult Azure Load Balancer documentation