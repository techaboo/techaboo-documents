<#
.SYNOPSIS
    Azure Resource Dormancy Scanner - Identifies and reports dormant Azure resources

.DESCRIPTION
    This script scans Azure subscriptions to identify dormant resources including VMs and other resource types.
    It generates a timestamped CSV report with resource details and creates a pie chart visualization
    showing the breakdown of dormant resources by type and cost.

.PARAMETER SubscriptionId
    Specific Azure subscription ID to scan. If not provided, scans all accessible subscriptions.

.PARAMETER OutputPath
    Directory path where output files will be saved. Defaults to current directory.

.PARAMETER DormancyThresholdDays
    Number of days to consider a resource dormant. Defaults to 30 days.

.EXAMPLE
    .\AzureResourceUsageScript.ps1
    Scans all accessible subscriptions for dormant resources with default settings.

.EXAMPLE
    .\AzureResourceUsageScript.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -OutputPath "C:\Reports" -DormancyThresholdDays 60
    Scans specific subscription for resources dormant for more than 60 days.

.NOTES
    Author: TechAboo
    Version: 1.0
    Requires: Az PowerShell modules, ImportExcel module (optional for enhanced charts)
    
    Prerequisites:
    - Install-Module Az
    - Install-Module ImportExcel (optional, for enhanced Excel functionality)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Get-Location).Path,
    
    [Parameter(Mandatory = $false)]
    [int]$DormancyThresholdDays = 30
)

# Import required modules and check dependencies
function Initialize-Dependencies {
    Write-Host "Checking and importing required modules..." -ForegroundColor Green
    
    try {
        # Check for Az module
        if (-not (Get-Module -ListAvailable -Name Az)) {
            Write-Warning "Az PowerShell module not found. Please install with: Install-Module Az"
            throw "Missing required Az module"
        }
        
        # Import Az modules
        Import-Module Az.Accounts -Force
        Import-Module Az.Resources -Force
        Import-Module Az.Compute -Force
        Import-Module Az.Storage -Force
        Import-Module Az.Monitor -Force
        
        # Check for ImportExcel module (optional but preferred)
        $global:UseImportExcel = $false
        if (Get-Module -ListAvailable -Name ImportExcel) {
            Import-Module ImportExcel -Force
            $global:UseImportExcel = $true
            Write-Host "ImportExcel module loaded - Enhanced chart capabilities enabled" -ForegroundColor Green
        } else {
            Write-Warning "ImportExcel module not found. Charts will use COM automation. Install with: Install-Module ImportExcel"
        }
        
        Write-Host "Module initialization completed successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to initialize dependencies: $($_.Exception.Message)"
        throw
    }
}

# Connect to Azure
function Connect-ToAzure {
    Write-Host "Connecting to Azure..." -ForegroundColor Green
    
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Host "No active Azure context found. Please sign in..." -ForegroundColor Yellow
            Connect-AzAccount
        } else {
            Write-Host "Using existing Azure context: $($context.Account.Id)" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to connect to Azure: $($_.Exception.Message)"
        throw
    }
}

# Get all subscriptions or specific subscription
function Get-TargetSubscriptions {
    param([string]$SpecificSubscriptionId)
    
    try {
        if ($SpecificSubscriptionId) {
            $subscriptions = Get-AzSubscription -SubscriptionId $SpecificSubscriptionId
        } else {
            $subscriptions = Get-AzSubscription
        }
        
        Write-Host "Found $($subscriptions.Count) subscription(s) to scan" -ForegroundColor Green
        return $subscriptions
    }
    catch {
        Write-Error "Failed to get subscriptions: $($_.Exception.Message)"
        throw
    }
}

# Check VM dormancy status
function Get-VMDormancyInfo {
    param([object]$VM, [int]$ThresholdDays)
    
    try {
        $dormancyInfo = @{
            IsDormant = $false
            Reason = ""
            DurationDays = 0
            LastActivity = $null
        }
        
        # Check VM power state
        $vmStatus = Get-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Status
        $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like "PowerState/*" }).DisplayStatus
        
        if ($powerState -eq "VM deallocated" -or $powerState -eq "VM stopped") {
            # Get VM activity logs to determine when it was last running
            $endTime = Get-Date
            $startTime = $endTime.AddDays(-90)  # Look back 90 days maximum
            
            try {
                $activityLogs = Get-AzActivityLog -ResourceId $VM.Id -StartTime $startTime -EndTime $endTime -WarningAction SilentlyContinue
                $lastPowerOnActivity = $activityLogs | Where-Object { 
                    $_.OperationName.Value -eq "Microsoft.Compute/virtualMachines/start/action" -or
                    $_.OperationName.Value -eq "Microsoft.Compute/virtualMachines/restart/action"
                } | Sort-Object EventTimestamp -Descending | Select-Object -First 1
                
                if ($lastPowerOnActivity) {
                    $daysSinceLastActivity = (Get-Date - $lastPowerOnActivity.EventTimestamp).Days
                    $dormancyInfo.LastActivity = $lastPowerOnActivity.EventTimestamp
                    $dormancyInfo.DurationDays = $daysSinceLastActivity
                    
                    if ($daysSinceLastActivity -ge $ThresholdDays) {
                        $dormancyInfo.IsDormant = $true
                        $dormancyInfo.Reason = "VM $powerState for $daysSinceLastActivity days"
                    }
                } else {
                    # No recent activity found, assume dormant
                    $dormancyInfo.IsDormant = $true
                    $dormancyInfo.Reason = "VM $powerState - no recent start activity found"
                    $dormancyInfo.DurationDays = 90  # Maximum lookback period
                }
            }
            catch {
                Write-Warning "Could not retrieve activity logs for VM $($VM.Name): $($_.Exception.Message)"
                $dormancyInfo.IsDormant = $true
                $dormancyInfo.Reason = "VM $powerState - activity logs unavailable"
            }
        } elseif ($powerState -eq "VM running") {
            # For running VMs, check CPU utilization
            try {
                $endTime = Get-Date
                $startTime = $endTime.AddDays(-$ThresholdDays)
                
                $cpuMetrics = Get-AzMetric -ResourceId $VM.Id -MetricName "Percentage CPU" -StartTime $startTime -EndTime $endTime -TimeGrain "PT1H" -WarningAction SilentlyContinue
                
                if ($cpuMetrics.Data) {
                    $avgCpuUsage = ($cpuMetrics.Data | Where-Object { $_.Average } | Measure-Object -Property Average -Average).Average
                    
                    if ($avgCpuUsage -lt 5) {  # Less than 5% average CPU usage
                        $dormancyInfo.IsDormant = $true
                        $dormancyInfo.Reason = "VM running but low CPU usage (avg: $([math]::Round($avgCpuUsage, 2))%)"
                        $dormancyInfo.DurationDays = $ThresholdDays
                    }
                }
            }
            catch {
                Write-Warning "Could not retrieve CPU metrics for VM $($VM.Name): $($_.Exception.Message)"
            }
        }
        
        return $dormancyInfo
    }
    catch {
        Write-Warning "Error checking VM dormancy for $($VM.Name): $($_.Exception.Message)"
        return @{
            IsDormant = $false
            Reason = "Error checking dormancy status"
            DurationDays = 0
            LastActivity = $null
        }
    }
}

# Check storage account dormancy
function Get-StorageAccountDormancyInfo {
    param([object]$StorageAccount, [int]$ThresholdDays)
    
    try {
        $dormancyInfo = @{
            IsDormant = $false
            Reason = ""
            DurationDays = 0
            LastActivity = $null
        }
        
        # Check storage account activity through metrics
        $endTime = Get-Date
        $startTime = $endTime.AddDays(-$ThresholdDays)
        
        try {
            $transactionMetrics = Get-AzMetric -ResourceId $StorageAccount.Id -MetricName "Transactions" -StartTime $startTime -EndTime $endTime -TimeGrain "PT1H" -WarningAction SilentlyContinue
            
            if ($transactionMetrics.Data) {
                $totalTransactions = ($transactionMetrics.Data | Where-Object { $_.Total } | Measure-Object -Property Total -Sum).Sum
                
                if ($totalTransactions -eq 0 -or $totalTransactions -lt 10) {  # Very low transaction count
                    $dormancyInfo.IsDormant = $true
                    $dormancyInfo.Reason = "Storage account with minimal activity (transactions: $totalTransactions)"
                    $dormancyInfo.DurationDays = $ThresholdDays
                }
            }
        }
        catch {
            Write-Warning "Could not retrieve storage metrics for $($StorageAccount.Name): $($_.Exception.Message)"
        }
        
        return $dormancyInfo
    }
    catch {
        Write-Warning "Error checking storage account dormancy for $($StorageAccount.Name): $($_.Exception.Message)"
        return @{
            IsDormant = $false
            Reason = "Error checking dormancy status"
            DurationDays = 0
            LastActivity = $null
        }
    }
}

# Get estimated resource cost (simplified calculation)
function Get-EstimatedResourceCost {
    param([object]$Resource)
    
    try {
        # This is a simplified cost estimation based on resource type and size
        # In a real implementation, you would use Azure Billing APIs
        
        $estimatedMonthlyCost = 0
        
        switch ($Resource.Type) {
            "Microsoft.Compute/virtualMachines" {
                $vmSize = $Resource.Properties.hardwareProfile.vmSize
                
                # Simplified cost estimation based on VM size (monthly USD estimates)
                $vmCostTable = @{
                    "Standard_B1s" = 7.30
                    "Standard_B1ms" = 14.60
                    "Standard_B2s" = 29.20
                    "Standard_B2ms" = 58.40
                    "Standard_D1_v2" = 55.50
                    "Standard_D2_v2" = 111.00
                    "Standard_D4_v2" = 222.00
                    "Standard_DS1_v2" = 66.60
                    "Standard_DS2_v2" = 133.20
                    "Standard_DS4_v2" = 266.40
                }
                
                if ($vmCostTable.ContainsKey($vmSize)) {
                    $estimatedMonthlyCost = $vmCostTable[$vmSize]
                } else {
                    $estimatedMonthlyCost = 100  # Default estimate for unknown sizes
                }
            }
            "Microsoft.Storage/storageAccounts" {
                $estimatedMonthlyCost = 25  # Base estimate for storage accounts
            }
            "Microsoft.Sql/servers/databases" {
                $estimatedMonthlyCost = 150  # Base estimate for SQL databases
            }
            default {
                $estimatedMonthlyCost = 50  # Default estimate for other resources
            }
        }
        
        return $estimatedMonthlyCost
    }
    catch {
        return 0
    }
}

# Scan for dormant resources in subscription
function Get-DormantResources {
    param([string]$SubscriptionId, [int]$ThresholdDays)
    
    Write-Host "Scanning subscription $SubscriptionId for dormant resources..." -ForegroundColor Green
    
    try {
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
        
        $dormantResources = @()
        
        # Get Virtual Machines
        Write-Host "  Checking Virtual Machines..." -ForegroundColor Yellow
        $vms = Get-AzVM
        foreach ($vm in $vms) {
            $dormancyInfo = Get-VMDormancyInfo -VM $vm -ThresholdDays $ThresholdDays
            
            if ($dormancyInfo.IsDormant) {
                $cost = Get-EstimatedResourceCost -Resource $vm
                
                $dormantResources += [PSCustomObject]@{
                    SubscriptionId = $SubscriptionId
                    ResourceName = $vm.Name
                    ResourceType = "Virtual Machine"
                    ResourceGroup = $vm.ResourceGroupName
                    Location = $vm.Location
                    ReasonForDormancy = $dormancyInfo.Reason
                    DurationDays = $dormancyInfo.DurationDays
                    LastActivity = $dormancyInfo.LastActivity
                    EstimatedMonthlyCost = $cost
                    ResourceId = $vm.Id
                    Tags = ($vm.Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ";"
                }
            }
        }
        
        # Get Storage Accounts
        Write-Host "  Checking Storage Accounts..." -ForegroundColor Yellow
        $storageAccounts = Get-AzStorageAccount
        foreach ($storageAccount in $storageAccounts) {
            $dormancyInfo = Get-StorageAccountDormancyInfo -StorageAccount $storageAccount -ThresholdDays $ThresholdDays
            
            if ($dormancyInfo.IsDormant) {
                $cost = Get-EstimatedResourceCost -Resource $storageAccount
                
                $dormantResources += [PSCustomObject]@{
                    SubscriptionId = $SubscriptionId
                    ResourceName = $storageAccount.StorageAccountName
                    ResourceType = "Storage Account"
                    ResourceGroup = $storageAccount.ResourceGroupName
                    Location = $storageAccount.Location
                    ReasonForDormancy = $dormancyInfo.Reason
                    DurationDays = $dormancyInfo.DurationDays
                    LastActivity = $dormancyInfo.LastActivity
                    EstimatedMonthlyCost = $cost
                    ResourceId = $storageAccount.Id
                    Tags = ($storageAccount.Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ";"
                }
            }
        }
        
        # Get other resource types (simplified check based on tags or naming patterns)
        Write-Host "  Checking other resource types..." -ForegroundColor Yellow
        $allResources = Get-AzResource | Where-Object { 
            $_.ResourceType -notin @("Microsoft.Compute/virtualMachines", "Microsoft.Storage/storageAccounts") -and
            $_.ResourceType -notlike "*microsoft.insights*" -and
            $_.ResourceType -notlike "*microsoft.network/networkwatchers*"
        }
        
        foreach ($resource in $allResources) {
            # Simple dormancy check based on naming patterns or tags
            $isDormant = $false
            $reason = ""
            
            if ($resource.Name -match "(test|temp|dev|deprecated|old|unused)" -or 
                $resource.Tags.Environment -match "(test|temp|dev|deprecated)" -or
                $resource.Tags.Status -match "(unused|deprecated|old)") {
                $isDormant = $true
                $reason = "Resource appears to be for testing/development or marked as unused"
            }
            
            if ($isDormant) {
                $cost = Get-EstimatedResourceCost -Resource $resource
                
                $dormantResources += [PSCustomObject]@{
                    SubscriptionId = $SubscriptionId
                    ResourceName = $resource.Name
                    ResourceType = $resource.ResourceType
                    ResourceGroup = $resource.ResourceGroupName
                    Location = $resource.Location
                    ReasonForDormancy = $reason
                    DurationDays = $ThresholdDays
                    LastActivity = $null
                    EstimatedMonthlyCost = $cost
                    ResourceId = $resource.ResourceId
                    Tags = ($resource.Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ";"
                }
            }
        }
        
        Write-Host "  Found $($dormantResources.Count) dormant resources in subscription $SubscriptionId" -ForegroundColor Green
        return $dormantResources
    }
    catch {
        Write-Error "Error scanning subscription $SubscriptionId : $($_.Exception.Message)"
        return @()
    }
}

# Export results to CSV
function Export-ResultsToCSV {
    param([array]$DormantResources, [string]$OutputPath)
    
    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $csvFileName = "AzureDormancyScan_$timestamp.csv"
        $csvFilePath = Join-Path $OutputPath $csvFileName
        
        Write-Host "Exporting results to CSV: $csvFilePath" -ForegroundColor Green
        
        $DormantResources | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
        
        Write-Host "CSV export completed successfully" -ForegroundColor Green
        return $csvFilePath
    }
    catch {
        Write-Error "Failed to export CSV: $($_.Exception.Message)"
        throw
    }
}

# Create pie chart using ImportExcel module
function New-ExcelPieChart {
    param([array]$DormantResources, [string]$OutputPath, [string]$CsvFilePath)
    
    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $excelFileName = "AzureDormancyScan_$timestamp.xlsx"
        $excelFilePath = Join-Path $OutputPath $excelFileName
        
        Write-Host "Creating Excel file with pie chart using ImportExcel module..." -ForegroundColor Green
        
        # Group data for pie chart
        $resourceTypeBreakdown = $DormantResources | Group-Object ResourceType | ForEach-Object {
            [PSCustomObject]@{
                ResourceType = $_.Name
                Count = $_.Count
                TotalCost = ($_.Group | Measure-Object EstimatedMonthlyCost -Sum).Sum
            }
        }
        
        # Create Excel file with data and charts
        $DormantResources | Export-Excel -Path $excelFilePath -WorksheetName "DormantResources" -AutoSize -BoldTopRow
        
        # Add summary worksheet with pie chart data
        $resourceTypeBreakdown | Export-Excel -Path $excelFilePath -WorksheetName "Summary" -AutoSize -BoldTopRow
        
        # Create pie charts
        $excel = Open-ExcelPackage -Path $excelFilePath
        
        # Resource count pie chart
        Add-ExcelChart -Worksheet $excel.Workbook.Worksheets["Summary"] -ChartType Pie -Title "Dormant Resources by Type (Count)" -XRange "A2:A$($resourceTypeBreakdown.Count + 1)" -YRange "B2:B$($resourceTypeBreakdown.Count + 1)" -Row 1 -Column 4 -Width 400 -Height 300
        
        # Cost pie chart
        Add-ExcelChart -Worksheet $excel.Workbook.Worksheets["Summary"] -ChartType Pie -Title "Dormant Resources by Type (Estimated Cost)" -XRange "A2:A$($resourceTypeBreakdown.Count + 1)" -YRange "C2:C$($resourceTypeBreakdown.Count + 1)" -Row 16 -Column 4 -Width 400 -Height 300
        
        Close-ExcelPackage $excel
        
        Write-Host "Excel file with pie charts created: $excelFilePath" -ForegroundColor Green
        return $excelFilePath
    }
    catch {
        Write-Error "Failed to create Excel pie chart: $($_.Exception.Message)"
        throw
    }
}

# Create pie chart using COM automation (fallback method)
function New-COMPieChart {
    param([array]$DormantResources, [string]$OutputPath)
    
    try {
        Write-Host "Creating pie chart using COM automation..." -ForegroundColor Green
        
        # Group data for pie chart
        $resourceTypeBreakdown = $DormantResources | Group-Object ResourceType | ForEach-Object {
            [PSCustomObject]@{
                ResourceType = $_.Name
                Count = $_.Count
                TotalCost = ($_.Group | Measure-Object EstimatedMonthlyCost -Sum).Sum
            }
        }
        
        if ($resourceTypeBreakdown.Count -eq 0) {
            Write-Warning "No data available for chart creation"
            return
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $chartImagePath = Join-Path $OutputPath "AzureDormancyChart_$timestamp.png"
        
        # Create Excel application
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        
        # Create workbook and worksheet
        $workbook = $excel.Workbooks.Add()
        $worksheet = $workbook.Worksheets.Item(1)
        
        # Add data to worksheet
        $worksheet.Cells.Item(1, 1) = "Resource Type"
        $worksheet.Cells.Item(1, 2) = "Count"
        $worksheet.Cells.Item(1, 3) = "Total Cost"
        
        for ($i = 0; $i -lt $resourceTypeBreakdown.Count; $i++) {
            $worksheet.Cells.Item($i + 2, 1) = $resourceTypeBreakdown[$i].ResourceType
            $worksheet.Cells.Item($i + 2, 2) = $resourceTypeBreakdown[$i].Count
            $worksheet.Cells.Item($i + 2, 3) = $resourceTypeBreakdown[$i].TotalCost
        }
        
        # Create pie chart for resource count
        $chartRange = $worksheet.Range("A1:B$($resourceTypeBreakdown.Count + 1)")
        $chart = $worksheet.Shapes.AddChart().Chart
        $chart.SetSourceData($chartRange)
        $chart.ChartType = 5  # xlPie
        $chart.HasTitle = $true
        $chart.ChartTitle.Text = "Dormant Azure Resources by Type"
        
        # Export chart as image
        $chart.Export($chartImagePath, "PNG")
        
        # Clean up
        $workbook.Close($false)
        $excel.Quit()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
        
        Write-Host "Pie chart saved as image: $chartImagePath" -ForegroundColor Green
        return $chartImagePath
    }
    catch {
        Write-Error "Failed to create COM pie chart: $($_.Exception.Message)"
        
        # Clean up on error
        try {
            if ($workbook) { $workbook.Close($false) }
            if ($excel) { $excel.Quit() }
            if ($excel) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null }
        }
        catch { }
        
        throw
    }
}

# Generate pie chart (uses ImportExcel if available, otherwise COM automation)
function New-PieChart {
    param([array]$DormantResources, [string]$OutputPath, [string]$CsvFilePath)
    
    try {
        if ($global:UseImportExcel) {
            return New-ExcelPieChart -DormantResources $DormantResources -OutputPath $OutputPath -CsvFilePath $CsvFilePath
        } else {
            return New-COMPieChart -DormantResources $DormantResources -OutputPath $OutputPath
        }
    }
    catch {
        Write-Error "Chart generation failed: $($_.Exception.Message)"
        Write-Host "Continuing without chart generation..." -ForegroundColor Yellow
        return $null
    }
}

# Main execution function
function Start-AzureDormancyScan {
    param([string]$SubscriptionId, [string]$OutputPath, [int]$DormancyThresholdDays)
    
    try {
        Write-Host "=== Azure Resource Dormancy Scanner ===" -ForegroundColor Cyan
        Write-Host "Threshold: $DormancyThresholdDays days" -ForegroundColor Cyan
        Write-Host "Output Path: $OutputPath" -ForegroundColor Cyan
        Write-Host ""
        
        # Initialize dependencies
        Initialize-Dependencies
        
        # Connect to Azure
        Connect-ToAzure
        
        # Get target subscriptions
        $subscriptions = Get-TargetSubscriptions -SpecificSubscriptionId $SubscriptionId
        
        # Scan all subscriptions
        $allDormantResources = @()
        foreach ($subscription in $subscriptions) {
            Write-Host "Processing subscription: $($subscription.Name) ($($subscription.Id))" -ForegroundColor Green
            $subscriptionDormantResources = Get-DormantResources -SubscriptionId $subscription.Id -ThresholdDays $DormancyThresholdDays
            $allDormantResources += $subscriptionDormantResources
        }
        
        # Display summary
        Write-Host ""
        Write-Host "=== SCAN SUMMARY ===" -ForegroundColor Cyan
        Write-Host "Total dormant resources found: $($allDormantResources.Count)" -ForegroundColor Green
        
        if ($allDormantResources.Count -gt 0) {
            $totalEstimatedCost = ($allDormantResources | Measure-Object EstimatedMonthlyCost -Sum).Sum
            Write-Host "Total estimated monthly cost: `$$([math]::Round($totalEstimatedCost, 2))" -ForegroundColor Yellow
            
            # Group by resource type
            $resourceTypeSummary = $allDormantResources | Group-Object ResourceType | ForEach-Object {
                [PSCustomObject]@{
                    ResourceType = $_.Name
                    Count = $_.Count
                    EstimatedMonthlyCost = ($_.Group | Measure-Object EstimatedMonthlyCost -Sum).Sum
                }
            }
            
            Write-Host ""
            Write-Host "Breakdown by resource type:" -ForegroundColor Cyan
            $resourceTypeSummary | Format-Table -AutoSize
            
            # Export to CSV
            $csvFilePath = Export-ResultsToCSV -DormantResources $allDormantResources -OutputPath $OutputPath
            
            # Generate pie chart
            $chartFilePath = New-PieChart -DormantResources $allDormantResources -OutputPath $OutputPath -CsvFilePath $csvFilePath
            
            Write-Host ""
            Write-Host "=== OUTPUT FILES ===" -ForegroundColor Cyan
            Write-Host "CSV Report: $csvFilePath" -ForegroundColor Green
            if ($chartFilePath) {
                Write-Host "Chart File: $chartFilePath" -ForegroundColor Green
            }
        } else {
            Write-Host "No dormant resources found!" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "Azure dormancy scan completed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Error "Scan failed: $($_.Exception.Message)"
        Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        throw
    }
}

# Execute main function
try {
    Start-AzureDormancyScan -SubscriptionId $SubscriptionId -OutputPath $OutputPath -DormancyThresholdDays $DormancyThresholdDays
}
catch {
    Write-Host "Script execution failed. Please check the error messages above." -ForegroundColor Red
    exit 1
}