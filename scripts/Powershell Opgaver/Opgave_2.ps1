#Requires -RunAsAdministrator

# Simpelt script til at ændre størrelsen på et DHCP Scope
set-dhcpserverv4scope -ScopeId 10.0.20.0 -StartRange 10.0.20.50 -EndRange 10.0.20.200