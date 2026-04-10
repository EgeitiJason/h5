# Install the File Server role on the server
if (-not (Get-WindowsFeature -Name FS-FileServer).Installed) {
    Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools
} else {
    Write-Host "✓ File Server role is already installed."
}