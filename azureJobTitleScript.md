# Install the module if you haven't already
```powershell
Install-Module AzureAD

# Connect to Azure AD
```powershell
Connect-AzureAD

# Get the group object
```powershell
$group = Get-AzureADGroup -Filter "DisplayName eq 'VHC_O365_E1'"

# Get the members of the group and their job titles
```powershell
Get-AzureADGroupMember -ObjectId $group.ObjectId | Select-Object DisplayName, JobTitle