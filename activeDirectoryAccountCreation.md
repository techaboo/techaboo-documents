# Copy Active Directory User

```powershell
# Import Active Directory module
Import-Module ActiveDirectory

# Define the function to copy an AD user
function Copy-ADUser {
    param (
        [string]$SourceUsername,
        [string]$NewUsername,
        [string]$NewUserPassword
    )

    # Get source user details
    $SourceUser = Get-ADUser -Identity $SourceUsername -Properties *
    
    # Create new user
    New-ADUser -Name $SourceUser.Name `
               -GivenName $SourceUser.GivenName `
               -Surname $SourceUser.Surname `
               -SamAccountName $NewUsername `
               -UserPrincipalName "$NewUsername@$($SourceUser.UserPrincipalName.Split('@')[1])" `
               -AccountPassword (ConvertTo-SecureString -AsPlainText $NewUserPassword -Force) `
               -Enabled $true
    
    # Add new user to groups
    $Groups = Get-ADUser -Identity $SourceUsername -Property MemberOf | Select-Object -ExpandProperty MemberOf
    foreach ($Group in $Groups) {
        Add-ADGroupMember -Identity $Group -Members $NewUsername
    }

    Write-Output "AD user $NewUsername created and added to groups."
}

# Copy AD user
$SourceUsername = "aabdulkadir@vasohealthcare.com"
$NewUsername = "operationtest@vasohealthcare.com"
$NewUserPassword = "Operation2024!"

Copy-ADUser -SourceUsername $SourceUsername -NewUsername $NewUsername -NewUserPassword $NewUserPassword
