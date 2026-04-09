#Requires -Modules ActiveDirectory

# Configuration
$config = @{
    DomainName = "prutl.internal"
    OuBase = "DC=prutl,DC=internal"
    OuCompany = "PRUTL"
}

# Define OU hierarchy - modify this structure to change OUs
$ouStructure = @(
    @{
        Name = "Servers"
        Children = @()
    },
    @{
        Name = "Users"
        Children = @(
            @{ Name = "Admin" },
            @{ Name = "Service Accounts" }
        )
    },
    @{
        Name = "Groups"
        Children = @(
            @{ Name = "Apps" },
            @{ Name = "Fileshares" }
        )
    },
    @{
        Name = "Computers"
        Children = @()
    }
)

<#
.SYNOPSIS
Creates an OU if it doesn't exist, or returns the path if it does.

.PARAMETER Name
The name of the OU to create.

.PARAMETER Path
The distinguished name (DN) path where the OU should be created.

.OUTPUTS
Returns the distinguished name of the created or existing OU.
#>
function New-OUIfNotExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        $ou = Get-ADOrganizationalUnit -Filter {Name -eq $Name} -SearchBase $Path -ErrorAction Stop
        Write-Host "✓ OU already exists: $Name"
        return $ou.DistinguishedName
    } catch {
        if ($_.Exception.Message -match "Cannot find") {
            try {
                New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true -ErrorAction Stop
                Write-Host "✓ Created OU: $Name"
                return "OU=$Name,$Path"
            } catch {
                Write-Error "Failed to create OU '$Name' at '$Path': $_"
                throw $_
            }
        } else {
            Write-Error "Error searching for OU '$Name': $_"
            throw $_
        }
    }
}

# Main execution
Write-Host "=== Creating Active Directory OU Structure ===" -ForegroundColor Cyan
$companyPath = "OU=$($config.OuCompany),$($config.OuBase)"

# Create company OU first
try {
    $null = New-OUIfNotExists -Name $config.OuCompany -Path $config.OuBase
} catch {
    Write-Error "Failed to create company OU. Exiting."
    exit 1
}

# Create child OUs
foreach ($ou in $ouStructure) {
    try {
        $ouPath = New-OUIfNotExists -Name $ou.Name -Path $companyPath
        
        # Create nested children if defined
        if ($ou.Children -and $ou.Children.Count -gt 0) {
            foreach ($child in $ou.Children) {
                $null = New-OUIfNotExists -Name $child.Name -Path $ouPath
            }
        }
    } catch {
        Write-Error "Failed to create OU '$($ou.Name)'"
    }
}

Write-Host "=== OU Structure Creation Complete ===" -ForegroundColor Cyan
