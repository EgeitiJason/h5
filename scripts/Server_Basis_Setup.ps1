# Make parameters
param (
    [Parameter(Mandatory = $true)]
    [string]$Hostname
)

# Make Veriables 
$DomainName = "prutl.internal" 
$Password = (ConvertTo-SecureString -String "Password1!" -AsPlainText -Force)
$Username = "$DomainName\Administrator"
$Credential = New-Object System.Management.Automation.PSCredential ($Username, $Password)
$possibleDrives = 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'

# Create a scheduler task, only if it does not already exist, to run this script on boot, run task as system
$taskName = "Server_Basis_Setup"
if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"$($MyInvocation.MyCommand.Path)`" -Hostname $Hostname"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -RunLevel Highest -User "SYSTEM"
}

# Check if the computer name is already set to '$Hostname'
$computerName = Get-ComputerInfo | Select-Object -ExpandProperty 'CsName'
if ($computerName -ne $Hostname) {
    Rename-Computer -NewName $Hostname
    Restart-Computer
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
    
if ((Get-WmiObject -Class Win32_ComputerSystem).Domain -eq "WORKGROUP") {
    Add-Computer -DomainName $DomainName -OUPath "OU=Servers,OU=PRUTL,DC=prutl,DC=internal" -Credential $Credential -Restart
    # After all configurations, restart the computer
    Restart-Computer
}

# Set CD/DVD Drives to the last available drive letter, starting from 'Z' and moving backwards:
Get-CimInstance -ClassName Win32_Volume -Filter "DriveType = '5'" | ForEach-Object {
    $usedDrives = Get-Volume | Select-Object -ExpandProperty DriveLetter | Where-Object { $_ -ne $null }
    $Driveletter = $possibleDrives | Where-Object { $_ -notin $usedDrives } | Select-Object -Last 1

    $_ | Set-CimInstance -Property @{ DriveLetter = "$($Driveletter):"}
}

# Get the offline disk
Get-Disk | Where-Object { $_.PartitionStyle -eq "RAW" } | ForEach-Object `
{
    # Dynamically find the next available drive letter starting from 'D'
    $usedDrives = Get-Volume | Select-Object -ExpandProperty DriveLetter | Where-Object { $_ -ne $null }
    $Driveletter = $possibleDrives | Where-Object { $_ -notin $usedDrives } | Select-Object -First 1
    $DiskNumber = $_.Number
    $null = Initialize-Disk -Number $DiskNumber -PartitionStyle GPT
    $Partition = New-Partition -DiskNumber $DiskNumber -UseMaximumSize
    $null = Add-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $Partition.PartitionNumber -AccessPath "${Driveletter}:"
    $null = Format-Volume -DriveLetter "$Driveletter" -FileSystem NTFS -Confirm:$false
    Write-Host "Initilizing unallocated disk to Driveletter ${Driveletter}:"
}

#delete the scheduled task after it has run
$taskName = "Server_Basis_Setup"
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false