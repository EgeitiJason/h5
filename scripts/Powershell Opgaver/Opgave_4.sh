#!/bin/bash

# Opgave 4 - Zabbix Server og Agent
# Opret en container med Zabbix Server og Agent installeret og konfigureret til at rapportere til Zabbix Serveren.
mode=generated var_hostname="HQ-ZABBIX-01" var_net="static" var_gateway="10.0.10.1" var_net="10.0.10.19/24" var_vlan="10" var_pw="Password1!" var_timezone="Europe/Copenhagen" var_ns="10.0.10.10" var_container_storage="local-zfs" var_template_storage="server-iso" bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/zabbix.sh)"