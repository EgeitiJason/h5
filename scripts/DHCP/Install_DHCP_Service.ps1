#install the DHCP sevice role and authorize the server to be able to manage DHCP
if (-not (Get-WindowsFeature -Name DHCP).Installed) {
    Install-WindowsFeature -Name DHCP -IncludeManagementTools
    Add-DhcpServerInDC -DnsName "$($env:COMPUTERNAME).$($env:DOMAINNAME)"
}