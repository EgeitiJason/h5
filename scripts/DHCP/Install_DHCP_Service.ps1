#install the DHCP sevice role
if (-not (Get-WindowsFeature -Name DHCP).Installed) {
    Install-WindowsFeature -Name DHCP -IncludeManagementTools
}