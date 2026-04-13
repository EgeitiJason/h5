# Make Veriables 
$DomainName = "prutl.internal"
$NetworkID = "10.0.10"   
$DNSForworder = "10.142.12.2"
$Reverselookup = "10.0.10.in-addr.arpa"
$Prefix = "24"
$NetworkIDPrefix = "$NetworkID.0/$Prefix"
$Password = (ConvertTo-SecureString -String "Password1!" -AsPlainText -Force)
$SiteName = "HQ"
$Sites = @("Aeroe","Naksov")
$DefaultSiteLink = "Prutl-Site-Link"


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

$SiteLink = Get-ADReplicationSiteLink -Filter 'Name -eq "DEFAULTIPSITELINK"'
if ($SiteLink.Name -eq "DEFAULTIPSITELINK") {
    Write-Host "Renaming default site link to $DefaultSiteLink"
    Rename-ADObject -Identity $SiteLink.DistinguishedName -NewName $DefaultSiteLink
} else {
    Write-Host "Default site link is already renamed"
}

$ExistingSites = Get-ADObject `
    -SearchBase (Get-ADRootDSE).ConfigurationNamingContext `
    -Filter "objectClass -eq 'site'" |
    Select-Object -ExpandProperty Name
if ($ExistingSites.Name -eq "Default-First-Site-Name") {
    Write-Host "Renaming default site to $SiteName"
    Rename-ADObject -Identity $ExistingSites -NewName $SiteName
} else {
    Write-Host "Default site is already renamed"
}

foreach ($Site in $Sites) {
    if ($Site -notin $ExistingSites) {
        Write-Host "Creating site: $Site"
        New-ADReplicationSite -Name $Site -
    }
    else {
        Write-Host "Site $Site already exists"
    }
}

function New-ADSubnet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Subnet,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$SiteName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Description,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Location
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            $Configuration = ([ADSI]"LDAP://RootDSE").configurationNamingContext
            $SubnetsContainer = [ADSI]"LDAP://CN=Subnets,CN=Sites,$Configuration"

            Write-Verbose "$Subnet - Creating subnet..."

            $SubnetObject = $SubnetsContainer.Create('subnet', "CN=$Subnet")
            $SubnetObject.Put("siteObject", "CN=$SiteName,CN=Sites,$Configuration")

            if ($Description) {
                $SubnetObject.Put("description", $Description)
            }

            if ($Location) {
                $SubnetObject.Put("location", $Location)
            }

            $SubnetObject.SetInfo()

            Write-Verbose "$Subnet - Subnet added."
        }
        catch {
            Write-Warning "Failed creating subnet $Subnet"
            $_.Exception.Message
        }
    }
}

Import-Csv "C:\temp\julian\subnets.csv" | New-ADSubnet -Verbose