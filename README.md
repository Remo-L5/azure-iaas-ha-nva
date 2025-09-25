# Azure IaaS High Availability Network Virtual Appliance (NVA)

A reference implementation for deploying highly available Network Virtual Appliances in Azure using Azure Verified Modules (AVM).

## Purpose

This repository serves as a public reference to help others deploy their services into Azure using proven, community-validated Azure Verified Modules. The implementation demonstrates best practices for high-availability network security appliance deployments.

## What's Included

- Terraform modules utilizing Azure Verified Modules
- High-availability architecture with dual load balancers
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

The Terraform configuration automatically accepts the Azure Marketplace terms for the Palo Alto VM-Series image during deployment. This eliminates the need to manually accept terms through the Azure portal or CLI before deployment.

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

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

This is a public repository intended to help the Azure community. Contributions, improvements, and feedback are welcome through pull requests and issues.