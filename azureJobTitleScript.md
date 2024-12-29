```powershell
# Install the module if you haven't already
Install-Module AzureAD

# Connect to Azure AD
Connect-AzureAD

# Get the group object
$group = Get-AzureADGroup -Filter "DisplayName eq 'VHC_O365_E1'"

# Get the members of the group and their job titles
Get-AzureADGroupMember -ObjectId $group.ObjectId | Select-Object DisplayName, JobTitle