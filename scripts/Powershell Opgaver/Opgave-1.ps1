# Make Veriables 
$DomainName = "prutl.internal"
$Hostname01 = "HQ-DC-04"
$Password = (ConvertTo-SecureString -String "Password1!" -AsPlainText -Force)
$Username = "$DomainName\Administrator"
$Credential = New-Object System.Management.Automation.PSCredential ($Username, $Password)

$computerName = Get-ComputerInfo | Select-Object -ExpandProperty 'CsName'
if ($computerName -ne $Hostname01) {
    Rename-Computer -NewName $Hostname01
}

# Install ADDS and DNS
$CheckAD = Get-WindowsFeature -Name AD-Domain-Services
if ($CheckAD.Installed -ne $true) {
    Write-Host "Installing AD-Domain-Services"
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    Install-ADDSDomainController -InstallDns -DomainName $DomainName -Credential $Credential -SafeModeAdministratorPassword  $Password -Force
    Restart-Computer
} else {
    Write-Host "AD-Domain-Services and DNS is already installed" 
}

