# vi laver en variabel for scope id for at gøre det nemmere at genbruge i resten af scriptet
$scopeId = "10.0.99.0"
$subnetMask = "255.255.255.0"
$domainName = "prutl.internal"

# vi skaber et DHCP Scope for klienter i rækkeviden 10.0.99.100-150
Add-DhcpServerV4Scope -Name "HQ MGMT Scope" -StartRange 10.0.99.100 -EndRange 10.0.99.150 -SubnetMask $subnetMask -State Active

# vi sætter en subnet mask for vores scope
Set-DhcpServerV4OptionValue -ScopeId $scopeId -OptionId 1 -Value $subnetMask

# vi definerer domain name for vores scope 
Set-DhcpServerV4OptionValue -ScopeId $scopeId -OptionId 15 -Value $domainName

# vi tilføjer en dns server der pejer på vores DC
Set-DhcpServerV4OptionValue -ScopeId $scopeId -OptionId 6 -Value 10.0.10.10

# vi opsætter en default gateway for vores scope
Set-DhcpServerV4OptionValue -ScopeId $scopeId -OptionId 3 -Value 10.0.99.1

# vi sætter en lease time på 7 dage
Set-DhcpServerV4Scope -ScopeId $scopeId -LeaseDuration 7.00:00:00