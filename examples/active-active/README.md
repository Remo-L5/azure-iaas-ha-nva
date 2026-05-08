# Palo Alto Active-Active Example

This example deploys **Palo Alto Networks VM-Series firewalls** in an active-active configuration with load balancing.

## Architecture

- **Vendor**: Palo Alto Networks
- **Topology**: Active-Active with dual load balancers
- **Load Balancing**: Enabled (external + internal LB)
- **Availability Zones**: VMs distributed across zones 1 and 2

## Key Configuration

| Setting | Value |
|---------|-------|
| `app_short_name` | `panfw` |
| `os_image.publisher` | `paloaltonetworks` |
| `os_image.offer` | `vmseries-flex` |
| `enable_load_balancing` | `true` (default) |

## Traffic Flow

```
Internet → External LB → Untrust NICs → Palo Alto FW → Trust NICs → Internal Network
Spokes   → Internal LB → Trust NICs   → Palo Alto FW → Untrust NICs → Internet
```

## Usage

1. Update `terraform.tfvars` with your values
2. Replace subnet resource IDs with your actual subnet paths
3. Configure your Key Vault resource ID
4. Accept the Palo Alto VM-Series marketplace terms (see below)

```bash
terraform init
terraform plan
terraform apply
```

## Marketplace Agreement

The Palo Alto VM-Series image requires accepting marketplace terms before deployment.

**Azure CLI:**

```bash
# Accept marketplace terms
az vm image terms accept --publisher paloaltonetworks --offer vmseries-flex --plan byol

# Verify the agreement was accepted
az vm image terms show --publisher paloaltonetworks --offer vmseries-flex --plan byol
```

**PowerShell:**

```powershell
# Accept Palo Alto VM-Series marketplace terms
Set-AzMarketplaceTerms -Publisher "paloaltonetworks" -Product "vmseries-flex" -Name "byol" -Accept

# Verify the agreement was accepted
Get-AzMarketplaceTerms -Publisher "paloaltonetworks" -Product "vmseries-flex" -Name "byol"
```
