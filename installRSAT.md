```powershell
# Get a list of all available RSAT features 
`Get-WindowsCapability -Name RSAT* -Online | Select-Object -Property DisplayName, State`

# Install all RSAT features
`Get-WindowsCapability -Name RSAT* -Online | Add-WindowsCapability -Online`
```
