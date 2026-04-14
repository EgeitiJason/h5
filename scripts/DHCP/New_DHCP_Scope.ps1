#requires -RunAsAdministrator

function New-DHCPScope {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScopeId,

        [Parameter(Mandatory = $true)]
        [string]$ScopeName,

        [Parameter(Mandatory = $true)]
        [string]$StartRange,

        [Parameter(Mandatory = $true)]
        [string]$EndRange,

        [Parameter(Mandatory = $true)]
        [string]$Gateway,

        [Parameter(Mandatory = $false)]
        [string]$SubnetMask = "255.255.255.0",

        [Parameter(Mandatory = $false)]
        [string]$DomainName = "prutl.internal",

        [Parameter(Mandatory = $false)]
        [string]$DNSServer = "10.0.10.10",

        [Parameter(Mandatory = $false)]
        [string]$LeaseDuration = "01:00:00"
    )

    try {
        Write-Host "Opretter DHCP scope: $ScopeName ($ScopeId)" -ForegroundColor Yellow

        # Opret DHCP scope
        Add-DhcpServerV4Scope -Name $ScopeName -ScopeId $ScopeId -StartRange $StartRange -EndRange $EndRange -SubnetMask $SubnetMask -State Active

        # Sæt subnet mask option
        Set-DhcpServerV4OptionValue -ScopeId $ScopeId -OptionId 1 -Value $SubnetMask

        # Sæt domain name
        Set-DhcpServerV4OptionValue -ScopeId $ScopeId -OptionId 15 -Value $DomainName

        # Sæt DNS server
        Set-DhcpServerV4OptionValue -ScopeId $ScopeId -OptionId 6 -Value $DNSServer

        # Sæt default gateway
        Set-DhcpServerV4OptionValue -ScopeId $ScopeId -OptionId 3 -Value $Gateway

        # Sæt lease duration
        Set-DhcpServerV4Scope -ScopeId $ScopeId -LeaseDuration $LeaseDuration

        Write-Host "DHCP scope $ScopeName er oprettet og konfigureret!" -ForegroundColor Green
    }
    catch {
        Write-Host "FEJL ved oprettelse af DHCP scope: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Eksempler på brug:

# HQ Scope
# New-DHCPScope -ScopeId "10.0.20.0" -ScopeName "HQ Client Scope" -StartRange "10.0.20.100" -EndRange "10.0.20.110" -Gateway "10.0.20.1"

# AE Scope
# New-DHCPScope -ScopeId "10.20.20.0" -ScopeName "AE Client Scope" -StartRange "10.20.20.100" -EndRange "10.20.20.110" -Gateway "10.20.20.1"

# NK Scope
# New-DHCPScope -ScopeId "10.10.20.0" -ScopeName "NK Client Scope" -StartRange "10.10.20.100" -EndRange "10.10.20.110" -Gateway "10.10.20.1"

# HQ MGMT Scope (med længere lease)
# New-DHCPScope -ScopeId "10.0.99.0" -ScopeName "HQ MGMT Scope" -StartRange "10.0.99.100" -EndRange "10.0.99.150" -Gateway "10.0.99.1" -LeaseDuration "7.00:00:00"