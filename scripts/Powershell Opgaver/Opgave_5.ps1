#Ændre mappe rettigheder fra everyone til kun en Security Group "File-Administration"
$folderPath = "E:\fortrolig"
$acl = Get-Acl $folderPath
$acl.SetAccessRuleProtection($true, $false) # fjerne arve rettigheder
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) } # Fjerner eksisterende rettigheder
$inheritanceFlags = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
$accessRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
    "File-Administration",
    [System.Security.AccessControl.FileSystemRights]::FullControl,
    $inheritanceFlags,
    [System.Security.AccessControl.PropagationFlags]::None,
    [System.Security.AccessControl.AccessControlType]::Allow
)
$acl.AddAccessRule($accessRule) # Tilføjer rettigheder for File-Administration
Set-Acl -Path $folderPath -AclObject $acl # Anvender de nye rettigheder på mappen