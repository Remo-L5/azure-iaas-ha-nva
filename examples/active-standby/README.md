# F5 Big-IP Active-Standby Example

This example deploys **F5 Networks Big-IP** load balancers in an active-standby (failover) configuration.

## Architecture

- **Vendor**: F5 Networks
- **Topology**: Active-Standby with F5 Cloud Failover Extension
- **Load Balancing**: Disabled (uses F5 native failover)
- **Availability Zones**: VMs distributed across zones 1 and 2

## Key Configuration

| Setting | Value |
|---------|-------|
| `app_short_name` | `f5lb` |
| `os_image.publisher` | `f5-networks` |
| `os_image.offer` | `f5-big-ip-byol` |
| `os_image.sku` | `f5-big-all-2slot-byol` |
| `enable_load_balancing` | `false` |

## F5 Cloud Failover

This example includes:
- **User-assigned managed identity** for F5 to manage Azure resources
- **Storage account** for failover state tracking
- **Network interface tags** for F5 Cloud Failover Extension (`f5_cloud_failover_label`, `f5_cloud_failover_nic_map`)
- **Additional IP configurations** for floating/failover IPs

## Failover Mechanism

F5 Cloud Failover Extension manages IP address failover between nodes:
- Monitors active node health
- Moves floating IPs to standby on failure
- Uses Azure Storage for state synchronization

## Alerting

An Azure Monitor activity log alert is configured to notify when a failover event occurs (NIC IP configuration change). This provides visibility into failover events for operational awareness and incident response.

Provide an existing Action Group resource ID via the `failover_alert_action_group_id` variable:

| Variable | Description | Type | Required |
|----------|-------------|------|:--------:|
| `failover_alert_action_group_id` | Resource ID of the Azure Monitor Action Group to notify when an F5 failover occurs | `string` | yes |

## Prerequisites: Custom RBAC Role

This example references a **custom Azure role** named `Custom F5 Big-IP HA Operator (alz-platform-connectivity)` which must exist in your subscription before deployment. The user-assigned managed identity attached to the F5 VMs is granted this role at the resource group scope so the F5 Cloud Failover Extension can move IPs and read related resources during failover.

Create the role with the following definition (Azure CLI):

```bash
az role definition create --role-definition '{
  "Name": "Custom F5 Big-IP HA Operator (alz-platform-connectivity)",
  "Description": "Permissions required by F5 Cloud Failover Extension to perform failover operations.",
  "AssignableScopes": ["/subscriptions/<subscription-id>"],
  "Actions": [
    "Microsoft.Network/*/join/action",
    "Microsoft.Network/networkInterfaces/write",
    "Microsoft.Network/publicIPAddresses/write",
    "Microsoft.Network/routeTables/*/read",
    "Microsoft.Network/routeTables/*/write",
    "Microsoft.Storage/storageAccounts/read",
    "Microsoft.Storage/storageAccounts/blobServices/containers/read",
    "Microsoft.Storage/storageAccounts/blobServices/containers/write",
    "Microsoft.Authorization/*/read",
    "Microsoft.Compute/locations/*/read",
    "Microsoft.Compute/virtualMachines/*/read",
    "Microsoft.Compute/virtualMachineScaleSets/*/read",
    "Microsoft.Compute/virtualMachineScaleSets/networkInterfaces/read",
    "Microsoft.Network/networkInterfaces/read",
    "Microsoft.Network/publicIPAddresses/read",
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "*/read",
    "Microsoft.Compute/virtualMachines/extensions/*",
    "Microsoft.HybridCompute/machines/extensions/write",
    "Microsoft.Insights/alertRules/*",
    "Microsoft.Insights/diagnosticSettings/*",
    "Microsoft.Insights/Register/Action",
    "Microsoft.OperationalInsights/*",
    "Microsoft.OperationsManagement/*",
    "Microsoft.Resources/deployments/*",
    "Microsoft.Resources/subscriptions/read",
    "Microsoft.Resources/subscriptions/resourceGroups/deployments/*",
    "Microsoft.Storage/storageAccounts/listKeys/action",
    "Microsoft.Support/*"
  ],
  "NotActions": [],
  "DataActions": [
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
    "Microsoft.Insights/Metrics/Write",
    "Microsoft.Insights/Telemetry/Write"
  ],
  "NotDataActions": []
}'
```

If you prefer a different role name, update the `data "azurerm_role_definition" "failover"` block in `main.tf`.

## Usage

1. Update `terraform.tfvars` with your values
2. Replace subnet and private DNS zone resource IDs
3. Configure your Key Vault resource ID
4. Set static IP addresses in `node_configuration` and `additional_ip_configurations`
5. Accept the F5 Big-IP marketplace terms (see below)

```bash
terraform init
terraform plan
terraform apply
```

## Marketplace Agreement

The F5 Big-IP image requires accepting marketplace terms before deployment.

**Azure CLI:**

```bash
# Accept marketplace terms
az vm image terms accept --publisher f5-networks --offer f5-big-ip-byol --plan f5-big-all-2slot-byol

# Verify the agreement was accepted
az vm image terms show --publisher f5-networks --offer f5-big-ip-byol --plan f5-big-all-2slot-byol
```

**PowerShell:**

```powershell
# Accept F5 Big-IP marketplace terms
Set-AzMarketplaceTerms -Publisher "f5-networks" -Product "f5-big-ip-byol" -Name "f5-big-all-2slot-byol" -Accept

# Verify the agreement was accepted
Get-AzMarketplaceTerms -Publisher "f5-networks" -Product "f5-big-ip-byol" -Name "f5-big-all-2slot-byol"
```

## Post-Deployment

Configure F5 Cloud Failover Extension on both devices following the [F5 documentation](https://clouddocs.f5.com/products/extensions/f5-cloud-failover/latest/userguide/azure.html).
