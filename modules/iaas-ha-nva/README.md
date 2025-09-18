# Azure IaaS High Availability Network Virtual Appliance (NVA)

A Terraform module for deploying highly available Network Virtual Appliances (specifically designed for Palo Alto Networks firewalls) in Azure with dual load balancers for comprehensive traffic management.

## Overview

This module abstracts the complexity of deploying a high-availability firewall solution in Azure by providing a simple interface that accepts a `node_configuration` map to deploy VMs across multiple availability zones. The architecture is designed to scale horizontally and can be extended in the future as needed.

## Architecture

The module deploys the following components:

### Core Infrastructure
- **Virtual Machines**: Palo Alto firewall appliances deployed across availability zones
- **Network Interfaces**: Each VM has two NICs (trust and untrust subnets)
- **External Load Balancer**: Public-facing load balancer with public IP
- **Internal Load Balancer**: Private load balancer for spoke network routing
- **Resource Group**: Managed with consistent naming conventions

### Network Flow Design

```
Internet Traffic Flow:
Internet → External LB (Public IP) → Untrust NICs → Palo Alto Firewall → Trust NICs → Internal Network

Spoke Network Traffic Flow:
Spoke Networks → Internal LB (Next-hop) → Trust NICs → Palo Alto Firewall → Untrust NICs → Internet
```

### Load Balancer Configuration

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
- **Load Balancing Rules**: HTTP and HTTPS traffic distribution

## Features

- ✅ **High Availability**: Zone-redundant deployment across multiple availability zones
- ✅ **Scalability**: Easy horizontal scaling by updating the node configuration
- ✅ **Dual Load Balancers**: Separate external and internal load balancers for optimal traffic flow
- ✅ **Automated Backend Pool Management**: Dynamic association of VMs to load balancer backend pools
- ✅ **Marketplace Agreement**: Automatic acceptance of Palo Alto marketplace terms
- ✅ **Consistent Naming**: Azure naming module for standardized resource names
- ✅ **Security**: Key Vault integration for VM credentials
- ✅ **Monitoring**: Built-in health probes for load balancers
- ✅ **Comprehensive Logging**: Log Analytics integration with diagnostic settings
- ✅ **Performance Monitoring**: Data collection rules for VM performance metrics
- ✅ **Centralized Monitoring**: Optional Log Analytics workspace integration

## Usage

### Basic Example

```hcl
module "palo_alto_ha" {
  source = "./modules/iaas-ha-nva"
  
  # Basic Configuration
  subscription_id  = "your-subscription-id"
  location        = "East US 2"
  environment     = "prod"
  app_short_name  = "pan"
  
  # VM Configuration
  sku_size = "Standard_D3_v2"
  os_type  = "Linux"
  
  # Palo Alto OS Image
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
    # Add more nodes as needed
  }
  
  # Network Configuration
  trust_private_ip_subnet_resource_id   = "/subscriptions/.../subnets/trust-subnet"
  untrust_private_ip_subnet_resource_id = "/subscriptions/.../subnets/untrust-subnet"
  
  # Security
  keyvault_resource_id = "/subscriptions/.../vaults/your-keyvault"
  
  # Monitoring and Logging (Optional)
  log_analytics_workspace_resource_id = "/subscriptions/.../workspaces/your-log-analytics"
  diagnostic_log_retention_days       = 30
  
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
| node_configuration | Map of node configurations with AZ and suffix | `map(object({availability_zone = number, sequence_suffix = string}))` | n/a | yes |
| trust_private_ip_subnet_resource_id | Resource ID of the trust subnet | `string` | n/a | yes |
| untrust_private_ip_subnet_resource_id | Resource ID of the untrust subnet | `string` | n/a | yes |
| keyvault_resource_id | Resource ID of the Key Vault for credentials | `string` | n/a | yes |
| os_image | Palo Alto OS image configuration | `object({publisher = string, offer = string, sku = string, version = string})` | n/a | yes |
| sku_size | The SKU size of the virtual machine | `string` | `"Standard_DS1_v2"` | no |
| os_type | The OS type of the virtual machine | `string` | `"Linux"` | no |
| enable_telemetry | Enable telemetry for resources | `bool` | `false` | no |
| log_analytics_workspace_resource_id | Resource ID of Log Analytics workspace for monitoring | `string` | `null` | no |
| enable_diagnostic_settings | Enable diagnostic settings for resources | `bool` | `true` | no |
| enable_data_collection_rules | Enable data collection rules for performance monitoring | `bool` | `true` | no |
| diagnostic_log_retention_days | Number of days to retain diagnostic logs | `number` | `30` | no |
| tags | A map of tags to assign to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| untrust_network_interfaces | Map of untrust network interfaces for the NVA virtual machines |
| trust_network_interfaces | Map of trust network interfaces for the NVA virtual machines |
| external_load_balancer | External load balancer information including frontend IP and backend pools |
| internal_load_balancer | Internal load balancer information |
| data_collection_rule | Data collection rule for VM performance monitoring |
| vm_diagnostic_settings | Map of VM diagnostic settings |
| load_balancer_diagnostic_settings | Load balancer diagnostic settings |

## Prerequisites

1. **Azure Subscription**: Active Azure subscription with appropriate permissions
2. **Network Infrastructure**: Pre-existing VNet with trust and untrust subnets
3. **Key Vault**: Azure Key Vault for storing VM admin credentials
4. **Log Analytics Workspace**: (Optional) For centralized logging and monitoring
5. **Terraform**: Version 1.0 or higher
6. **Azure Provider**: Version 3.0 or higher

## Palo Alto Networks Specific Notes

- The module automatically accepts Palo Alto marketplace terms
- Ensure your Azure subscription has access to Palo Alto VM-Series images
- The default configuration uses BYOL (Bring Your Own License) SKU
- Health probes are configured for common Palo Alto management ports

## Best Practices

1. **Subnet Planning**: Ensure trust and untrust subnets are in different network security zones
2. **Routing**: Configure User Defined Routes (UDRs) to direct spoke traffic through the internal load balancer
3. **Security**: Use Azure Key Vault for credential management
4. **Monitoring**: Enable Azure Monitor and configure alerts for load balancer health
5. **Log Analytics**: Connect to a Log Analytics workspace for centralized monitoring
6. **Performance Monitoring**: Enable data collection rules for comprehensive VM monitoring
7. **Updates**: Regularly update to the latest Palo Alto VM-Series image versions

## Contributing

Please read our contributing guidelines and submit pull requests to the main branch.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and questions:
1. Check the [Issues](../../issues) section
2. Review Palo Alto Networks documentation
3. Consult Azure Load Balancer documentation