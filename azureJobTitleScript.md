# Azure Job Title trigger for old sec groups

1. First install the AzureAD module: ```Install-Module AzureAD```




2. Second connect to the AzureAD module: ```Connect-AzureAD```


3. Change the "VHC_0365_E1": ```$group = Get-AzureADGroup -Filter "DisplayName eq 'VHC_O365_E1'"```

4. This will bring the result: ```Get-AzureADGroupMember -ObjectId $group.ObjectId | Select-Object DisplayName, JobTitle```