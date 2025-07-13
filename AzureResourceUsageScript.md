# Azure Resource Dormancy Scanner

## Overview
The `AzureResourceUsageScript.ps1` is a comprehensive PowerShell script designed to identify and report dormant Azure resources across your Azure subscriptions. It generates detailed CSV reports and visual pie charts to help you understand resource utilization and potential cost savings.

## Features
- **Multi-subscription scanning**: Scan specific subscriptions or all accessible subscriptions
- **Multiple resource type support**: Identifies dormant Virtual Machines, Storage Accounts, and other Azure resources
- **Intelligent dormancy detection**: Uses various criteria including VM power state, CPU utilization, storage activity, and naming patterns
- **Timestamped reports**: Generates CSV files with timestamp naming (e.g., `AzureDormancyScan_20250713-040127.csv`)
- **Visual reporting**: Creates pie charts showing resource breakdown by type and estimated costs
- **Flexible chart generation**: Uses ImportExcel module when available, falls back to COM automation
- **Cost estimation**: Provides estimated monthly costs for dormant resources
- **Comprehensive logging**: Detailed progress information and error handling

## Prerequisites

### Required PowerShell Modules
```powershell
# Install Azure PowerShell modules
Install-Module Az -Force -AllowClobber

# Optional but recommended for enhanced Excel functionality
Install-Module ImportExcel -Force
```

### Required Permissions
- **Reader** access to Azure subscriptions you want to scan
- **Monitoring Reader** access for retrieving metrics and activity logs
- Permission to access Azure Resource Manager APIs

## Usage

### Basic Usage
```powershell
# Scan all accessible subscriptions with default settings (30-day threshold)
.\AzureResourceUsageScript.ps1
```

### Advanced Usage
```powershell
# Scan specific subscription with custom threshold and output path
.\AzureResourceUsageScript.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -OutputPath "C:\Reports" -DormancyThresholdDays 60

# Scan with 90-day threshold for more conservative dormancy detection
.\AzureResourceUsageScript.ps1 -DormancyThresholdDays 90
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `SubscriptionId` | String | No | All accessible | Specific Azure subscription ID to scan |
| `OutputPath` | String | No | Current directory | Directory where output files will be saved |
| `DormancyThresholdDays` | Integer | No | 30 | Number of days to consider a resource dormant |

## Dormancy Detection Criteria

### Virtual Machines
- **Stopped/Deallocated VMs**: Checks VM power state and activity logs
- **Low CPU utilization**: Running VMs with less than 5% average CPU usage over the threshold period
- **Activity log analysis**: Reviews start/restart activities to determine last usage

### Storage Accounts
- **Low transaction activity**: Storage accounts with minimal transaction counts
- **Metrics-based detection**: Uses Azure Monitor metrics to assess activity levels

### Other Resources
- **Naming pattern analysis**: Resources with names containing "test", "temp", "dev", "deprecated", etc.
- **Tag-based detection**: Resources tagged with development, testing, or deprecated statuses

## Output Files

### CSV Report
The CSV report includes the following columns:
- **SubscriptionId**: Azure subscription identifier
- **ResourceName**: Name of the dormant resource
- **ResourceType**: Type of Azure resource (Virtual Machine, Storage Account, etc.)
- **ResourceGroup**: Resource group containing the resource
- **Location**: Azure region where the resource is deployed
- **ReasonForDormancy**: Detailed explanation of why the resource is considered dormant
- **DurationDays**: Number of days the resource has been dormant
- **LastActivity**: Timestamp of last detected activity (if available)
- **EstimatedMonthlyCost**: Estimated monthly cost in USD
- **ResourceId**: Full Azure resource identifier
- **Tags**: Resource tags (semicolon-separated key=value pairs)

### Chart Files
Depending on available modules, the script generates:
- **Excel file with embedded charts** (when ImportExcel module is available)
- **PNG image file** (when using COM automation fallback)

Charts include:
- Resource count breakdown by type
- Cost breakdown by resource type

## Error Handling

The script includes comprehensive error handling for:
- **Authentication failures**: Clear messages when Azure connection fails
- **Permission issues**: Warnings when unable to access specific resources or metrics
- **Module dependencies**: Checks for required modules and provides installation guidance
- **Chart generation failures**: Graceful fallback when chart creation fails
- **Subscription access**: Handles subscription-level access issues

## Example Output

### Console Output
```
=== Azure Resource Dormancy Scanner ===
Threshold: 30 days
Output Path: C:\Reports

Checking and importing required modules...
ImportExcel module loaded - Enhanced chart capabilities enabled
Module initialization completed successfully
Connecting to Azure...
Using existing Azure context: user@company.com
Found 3 subscription(s) to scan
Processing subscription: Production (12345678-1234-1234-1234-123456789012)
Scanning subscription 12345678-1234-1234-1234-123456789012 for dormant resources...
  Checking Virtual Machines...
  Checking Storage Accounts...
  Checking other resource types...
  Found 5 dormant resources in subscription 12345678-1234-1234-1234-123456789012

=== SCAN SUMMARY ===
Total dormant resources found: 5
Total estimated monthly cost: $267.50

Breakdown by resource type:
ResourceType      Count EstimatedMonthlyCost
------------      ----- --------------------
Virtual Machine       3                  195
Storage Account       2                 72.5

=== OUTPUT FILES ===
CSV Report: C:\Reports\AzureDormancyScan_20250713-040127.csv
Chart File: C:\Reports\AzureDormancyScan_20250713-040127.xlsx

Azure dormancy scan completed successfully!
```

## Best Practices

1. **Regular scanning**: Run the script monthly to track dormant resources
2. **Custom thresholds**: Adjust dormancy thresholds based on your organization's usage patterns
3. **Review before action**: Always review dormant resource reports before taking cleanup actions
4. **Tag compliance**: Use consistent tagging strategies to improve dormancy detection accuracy
5. **Cost monitoring**: Use the cost estimates as guidance for prioritizing cleanup efforts

## Troubleshooting

### Common Issues

#### "Az module not found"
```powershell
Install-Module Az -Force -AllowClobber
```

#### "No active Azure context found"
```powershell
Connect-AzAccount
```

#### "Could not retrieve activity logs"
Ensure you have **Monitoring Reader** permissions on the subscriptions being scanned.

#### "Chart generation failed"
This is typically due to missing Excel installation or COM permissions. The script will continue without chart generation.

## Cost Estimation Methodology

The script provides simplified cost estimates based on:
- **VM sizing**: Predefined cost table for common VM sizes
- **Resource type**: Base estimates for different Azure resource types
- **Regional considerations**: Uses general pricing (may vary by region)

**Note**: These are estimates only. For accurate billing information, use Azure Cost Management tools.

## Security Considerations

- The script only requires **read permissions** to Azure resources
- No resource modifications are performed
- All authentication uses standard Azure PowerShell methods
- Output files may contain sensitive information - store securely

## Contributing

To enhance the script:
1. Add new resource type detection logic
2. Improve cost estimation accuracy
3. Add support for additional Azure regions
4. Enhance chart visualization options

## Version History

- **v1.0**: Initial release with VM, Storage Account, and basic resource detection
- Support for timestamped outputs and dual chart generation methods
- Comprehensive error handling and logging