# Azure IaaS High Availability Network Virtual Appliance (NVA)

A reference implementation for deploying highly available Network Virtual Appliances in Azure using Azure Verified Modules (AVM).

## Purpose

This repository serves as a public reference to help others deploy their services into Azure using proven, community-validated Azure Verified Modules. The implementation demonstrates best practices for high-availability network security appliance deployments.

## What's Included

- Terraform modules utilizing Azure Verified Modules
- High-availability architecture with dual load balancers
- Optional Gateway Load Balancer service chaining with HA Ports load balancing
- Multi-zone deployment patterns
- Comprehensive documentation and examples

## Prerequisites

Before deploying this solution, ensure you have registered the **Encryption at Host** feature in your Azure subscription:

```bash
# Register the Encryption at Host feature
az feature register --namespace Microsoft.Compute --name EncryptionAtHost

# Check registration status
az feature show --namespace Microsoft.Compute --name EncryptionAtHost

# Once registered, refresh the resource provider
az provider register --namespace Microsoft.Compute
```

> **Note**: Feature registration may take several minutes to complete. Verify the `state` shows as `"Registered"` before proceeding with deployment.

### Marketplace Agreement

The Terraform configuration includes automated marketplace agreement acceptance for the Palo Alto VM-Series image. **This code has been updated to use the correct AzAPI v2.x syntax but has not been fully tested yet.**

> **⚠️ NOTE**: If the automated acceptance fails during deployment, please manually accept the terms using one of the methods below before running `terraform apply`.

**Manual Acceptance - PowerShell:**

```powershell
# Accept Palo Alto VM-Series marketplace terms
Set-AzMarketplaceTerms -Publisher "paloaltonetworks" -Product "vmseries-flex" -Name "byol" -Accept

# Verify the agreement was accepted
Get-AzMarketplaceTerms -Publisher "paloaltonetworks" -Product "vmseries-flex" -Name "byol"
```

**Manual Acceptance - Azure CLI:**

```bash
# Accept marketplace terms
az vm image terms accept --publisher paloaltonetworks --offer vmseries-flex --plan byol

# Verify the agreement was accepted
az vm image terms show --publisher paloaltonetworks --offer vmseries-flex --plan byol
```

## Getting Started

Explore the `modules/iaas-ha-nva/` directory for the complete module implementation, including:
- Terraform configuration files
- Variable definitions
- Output specifications
- Usage examples

### Sample Terraform TFVARS

```hcl
location        = "your-location"
environment     = "your-environment"
subscription_id = "your-subscription-id"
log_analytics_workspace_resource_id = "/subscriptions/.../workspaces/your-log-analytics"
```

### Enabling Gateway Load Balancer Service Chaining (Optional)

The root module exposes an object-based `service_chain_configuration` input that provisions:
- A dedicated service-chain NIC per VM
- A Standard Load Balancer configured with HA Ports (`frontend_port = 0`, `backend_port = 0`)
- Optional public IP creation when a Gateway Load Balancer frontend ID is not supplied

Below is a sample snippet you can adapt in your root configuration:

```hcl
service_chain_configuration = {
  subnet_resource_id                                 = "/subscriptions/.../subnets/service-chain"
  gateway_load_balancer_frontend_ip_configuration_id = "/subscriptions/.../loadBalancers/gwlb/frontendIPConfigurations/gwlb-frontend"
  probe_port                                         = 443
  frontend_port                                      = 0
  backend_port                                       = 0
  # create_public_ip_address defaults to true; public IP naming follows the module convention
}
```

If you supply the `gateway_load_balancer_frontend_ip_configuration_id`, the load balancer will chain to the specified Gateway Load Balancer. Leaving it `null` still creates the service-chain load balancer with a new public IP using the default naming convention (`pip-slb-svc-<app>-<location>-<environment>`).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

This is a public repository intended to help the Azure community. Contributions, improvements, and feedback are welcome through pull requests and issues.