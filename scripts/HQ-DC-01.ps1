# Make Veriables 
$Password = (ConvertTo-SecureString -String "Password1!" -AsPlainText -Force)
$InterfaceIndex = (Get-NetAdapter).InterfaceIndex
$InterfaceName = (Get-NetAdapter).Name
$DomainName = "prutl.internal"
$NetworkID = "10.0.10"   
$DNSServer01 = "10.0.10.10"
$Gateway01 = "10.0.10.1"
$DNSForworder = "10.142.12.2"
$StartRange = "101"
$EndRange = "199"
$SubnetMask = "255.255.255.0"
$Hostname01 = "HQ-DC-01"
$Reverselookup = "10.0.10.in-addr.arpa"
$Prefix = "24"
$NetworkIDPrefix = "$NetworkID.0/$Prefix"
$Driveletter = "D"




# Check if the computer name is already set to '$Hostname01'
$computerName = Get-ComputerInfo | Select-Object -ExpandProperty 'CsName'
if ($computerName -ne '$Hostname01') {
    Rename-Computer -NewName $Hostname01

    $adminUser = Get-LocalUser -Name "Administrator"
    if ($null -eq $adminUser.Password ) {
    Set-LocalUser -Name "Administrator" -Password $Password
    Write-Host "Administrator user password set."=
    }

    # Check if the network configuration is already set
    $networkConfig = Get-NetIPAddress | Where-Object { $_.IPAddress -eq $DNSServer01 }
    if ($null -eq $networkConfig) {
        netsh interface ipv4 set interface $InterfaceIndex dadtransmits=0 store=persistent
        New-NetIPAddress –IPAddress $DNSServer01 -DefaultGateway $Gateway01 -PrefixLength $Prefix -InterfaceIndex $InterfaceIndex
        Set-DNSClientServerAddress –InterfaceIndex $InterfaceIndex –ServerAddresses $DNSServer01
        Disable-NetAdapterBinding -Name $InterfaceName -ComponentID 'ms_tcpip6'
    }

    # Check if the time zone is already set to "Romance Standard Time"
    $timeZone = Get-TimeZone
    if ($timeZone.Id -ne "Romance Standard Time") {
        Set-TimeZone -Name "Romance Standard Time"
    }

    # Check if Terminal Services settings are already configured
    $tsConnections = Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections"
    if ($tsConnections.fDenyTSConnections -ne 0) {
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
    }

    $rdpAuthentication = Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication"
    if ($rdpAuthentication.UserAuthentication -ne 1) {
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 1
    }

    # Check if the Remote Desktop firewall rule is already enabled
    $rdpFirewallRule = Get-NetFirewallRule -DisplayGroup "Remote Desktop"
    if ($rdpFirewallRule.Enabled -eq 'False') {
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    }

    # After all configurations, restart the computer
    Restart-Computer
} else {
    Write-Host "Basic server configuration is already applied"
}



# Install ADDS and DNS
$CheckAD = Get-WindowsFeature -Name AD-Domain-Services
if ($CheckAD.Installed -ne $true) {
    Write-Host "Installing AD-Domain-Services"
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    Write-Host "Installing DNS"
    Install-WindowsFeature -Name DNS -IncludeManagementTools
    Import-Module ADDSDeployment
    Install-ADDSForest -DomainName $DomainName -SafeModeAdministratorPassword  $Password -Force
    Restart-Computer
} else {
    Write-Host "AD-Domain-Services and DNS is already installed" 
}

# Configure DNS forwarder and reverse lookup zone
if (-not (Get-DnsServerZone -Name $DomainName -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -Name $DomainName -ReplicationScope "Domain"
    Write-Host "Forward lookup zone created for $NetworkID"
} else {
    Write-Host "Forward lookup zone already exists"
}

# Check if a reverse lookup zone with the specified network ID exists
 if (-not (Get-DnsServerZone -Name $Reverselookup -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -NetworkID $NetworkIDPrefix -ReplicationScope "Domain" 
    Write-Host "Reverse lookup zone created for $NetworkIDPrefix"
} else {
    Write-Host "Reverse lookup zone already exists"
}


if ($existingForwarders.Count -eq 0) {
    Set-DNSServerForwarder -IPAddress $DNSForworder
    Write-Host "DNS forwarder set to $DNSForworder"
} else {
    Write-Host "DNS forwarder already exists"
}

Restart-Service -Name DNS

# Install DHCP and configure 
$CheckDHCP = Get-WindowsFeature -Name DHCP
if ($CheckDHCP.Installed -ne $true) {
    Write-Host "Installing AD-Domain-Services"
    Install-WindowsFeature -Name DHCP -IncludeManagementTools
    Add-DhcpServerv4Scope -Name "$NetworkID.0" -StartRange "$NetworkID.$StartRange" -EndRange "$NetworkID.$EndRange" -SubnetMask $SubnetMask
    Set-DhcpServerv4OptionValue -ScopeID "$NetworkID.0" -DNSServer $DNSServer01 -DNSDomain $DomainName -Router $Gateway01
    Add-DhcpServerInDC -DnsName "$Hostname01.$DomainName"
} else {
    Write-Host "DHCP is already installed and configured" 
}

# Set CD/DVD Drive to Z:
$cd = $null
$cd = Get-WmiObject -Class Win32_CDROMDrive -ComputerName $env:COMPUTERNAME -ErrorAction Stop 
if ($cd.Drive -eq "D:")
{
    Write-Host "Changing CD Drive letter from D: to Z:"
    $null = Set-WmiInstance -InputObject (Get-WmiObject -Class Win32_volume -Filter "DriveLetter = 'd:'") -Arguments @{DriveLetter='z:'}
} 

# Get the offline disk
$Disk = Get-Disk | Where-Object { $_.IsOffline -eq $True } | Select-Object -First 1
# Check if a disk was found
if ($Disk) {
    
    $DiskNumber = $Disk.Number
    $null = Initialize-Disk -Number $DiskNumber -PartitionStyle GPT
    $Partition = New-Partition -DiskNumber $DiskNumber -UseMaximumSize
    $null = Add-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $Partition.PartitionNumber -AccessPath "${Driveletter}:"
    $null = Format-Volume -DriveLetter "$Driveletter" -FileSystem NTFS -Confirm:$false
    Write-Host "Initilizing unallocated disk to Driveletter D:"
} else {
    Write-Host "No offline disk found."
}
