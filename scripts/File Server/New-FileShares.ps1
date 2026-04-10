# Create a server-iso folder on the D: drive to store the ISO files for the file server if it doesn't already exist
if (-not (Test-Path -Path "D:\server-iso")) {
    New-Item -Path "D:\server-iso" -ItemType Directory -Force
    Write-Host "✓ Created directory: D:\server-iso"
} else {
    Write-Host "✓ Directory already exists: D:\server-iso"
}

# Create the server-iso as a share on the file server if it doesn't already exist
if (-not (Get-SmbShare -Name "server-iso" -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name "server-iso" -Path "D:\server-iso" -FullAccess "Everyone"
    Write-Host "✓ Created SMB share: server-iso"
} else {
    Write-Host "✓ SMB share already exists: server-iso"
}