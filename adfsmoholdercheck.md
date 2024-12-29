>Make sure to run PowerShell as an admin before running the script below.
```powershell
# Function to retrieve FSMO role holders
function Get-FSMORoles {
    try {
        Write-Host "Retrieving FSMO role holders..." -ForegroundColor Green

&nbsp;       # Retrieve the Domain Naming Master role holder
        $domainNamingMaster = (Get-ADForest).DomainNamingMaster

&nbsp;       # Retrieve the Schema Master role holder
        $schemaMaster = (Get-ADForest).SchemaMaster

&nbsp;       # Retrieve other roles within the domain
        $domain = (Get-ADDomain)
        $pdcEmulator = $domain.PDCEmulator
        $ridMaster = $domain.RIDMaster
        $infrastructureMaster = $domain.InfrastructureMaster

&nbsp;       # Output role holders
        $fsmoroles = [PSCustomObject]@{
            Role = "Domain Naming Master"
            DC = $domainNamingMaster
        }, [PSCustomObject]@{
            Role = "Schema Master"
            DC = $schemaMaster
        }, [PSCustomObject]@{
            Role = "PDC Emulator"
            DC = $pdcEmulator
        }, [PSCustomObject]@{
            Role = "RID Master"
            DC = $ridMaster
        }, [PSCustomObject]@{
            Role = "Infrastructure Master"
            DC = $infrastructureMaster
        }

&nbsp;       # Display the FSMO role holders
        $fsmoroles | Format-Table -AutoSize

&nbsp;       # Export to CSV if needed
        $fsmoroles | Export-Csv -Path "C:\Reports\FSMORoles.csv" -NoTypeInformation
        Write-Host "FSMO roles exported to C:\Reports\FSMORoles.csv" -ForegroundColor Green

&nbsp;   } catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}

# Ensure ActiveDirectory module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Install-WindowsFeature RSAT-AD-PowerShell -IncludeAllSubFeature
    Import-Module ActiveDirectory
}

# Run the function
Get-FSMORoles
```