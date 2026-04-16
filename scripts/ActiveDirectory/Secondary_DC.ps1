param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("HQ","Aeroe","Nakskov")]
    [string] $Site
)
# Make Veriables 
$DomainName = "prutl.internal"
$Password = (ConvertTo-SecureString -String "Password1!" -AsPlainText -Force)
$Username = "$DomainName\Administrator"
$Credential = New-Object System.Management.Automation.PSCredential ($Username, $Password)



# Install ADDS and DNS, and rename default site to HQ
$CheckAD = Get-WindowsFeature -Name AD-Domain-Services
if ($CheckAD.Installed -ne $true) {
    Write-Host "Installing AD-Domain-Services"
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    Install-ADDSDomainController -InstallDns -DomainName $DomainName -Credential $Credential -SafeModeAdministratorPassword  $Password -Force


    Restart-Computer
} else {
    Write-Host "AD-Domain-Services and DNS is already installed" 
}