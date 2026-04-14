#vi laver en variabel for scope id for at gøre det nemmere at genbruge i resten af scriptet
$scopeId = "10.10.20.0"
$subnetMask = "255.255.255.0"
$domainName = "prutl.internal"

#vi skaber et DHCP Scope for NK i rækkeviden 10.10.20.100-110
Add-Dhcpserverv4scope -Name "NK client Scope" -StartRange 10.10.20.100 -EndRange 10.10.20.110

#vi definerer domain name for vores scope
Set-DhcpServerv4OptionValue -ScopeId $scopeId -OptionId 15 -Value $domainName

#vi tilføjer en dns server der pejer på vores DC
Set-DhcpServerv4OptionValue -ScopeId $scopeId -OptionId 6 -Value 10.0.10.10

#vi opsætter en default gateway for vores scope
Set-DhcpServerv4OptionValue -ScopeId $scopeId -OptionId 3 -Value 10.10.20.1

#vi sætter en lease time på 1 time
Set-DhcpServerv4Scope -ScopeId $scopeId -LeaseDuration 01:00:00