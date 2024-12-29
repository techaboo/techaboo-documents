# Install/Reinstall Chocolatey
## Reinstall Chocolatey on your system

```PowerShell
Set-ExecutionPolicy Bypass -Scope Process -Force;
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
```

## Uninstall Chocolatey from your system

```PowerShell
$chocoPath = "$env:ChocolateyInstall"
if ($chocoPath -ne $null -and $chocoPath -ne '') {
    # Remove Chocolatey environment variables
    [System.Environment]::SetEnvironmentVariable('ChocolateyInstall', $null, [System.EnvironmentVariableTarget]::Machine)
    
    # Remove Chocolatey from the path
    $path = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine)
    $newPath = ($path.Split(';') | Where-Object { $_ -notlike "*chocolatey*" }) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $newPath, [EnvironmentVariableTarget]::Machine)

    # Delete the Chocolatey directory
    Remove-Item -Recurse -Force "$chocoPath"

    
    Write-Host "Chocolatey has been uninstalled."
} else {
    Write-Host "Chocolatey is not installed."
}
```
