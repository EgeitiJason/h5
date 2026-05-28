# Updated Setup Guide with Revised Network Plan

Good catches on the network design. Let me address the Corosync question first, then give you the updated guide.

## On the Corosync separate VLANs question

**You can absolutely use a single VLAN/subnet for both Corosync rings if you want — but I'd recommend keeping them separate, and here's the honest reasoning:**

The point of two Corosync rings is **fault isolation**. If both rings share the same Layer 2 broadcast domain (same VLAN), then a single Layer 2 problem — broadcast storm, misconfigured switch port flooding the VLAN, MTU mismatch on the SVI, runaway ARP — takes down both rings simultaneously, and your cluster fences itself. The whole point of redundancy is gone.

With separate VLANs, the rings are independent failure domains at L2. A problem on VLAN 1020 doesn't touch VLAN 1030. Combined with the physical separation (ring 0 on stack member 1, ring 1 on stack member 2), you get genuine redundancy.

The cost of separate VLANs is essentially zero — two extra VLAN definitions on the switch and two `/24` subnets that nobody else uses. The benefit is real fault isolation.

**Recommendation: use the separate VLANs (1020 and 1030).** I'll build the guide that way. If you want the single-VLAN version anyway, swap in `172.16.0.0/24` VLAN 1000 — wait, that's Ceph. You'd want a single dedicated Corosync VLAN. Just let me know and I'll redo it.

## Revised network plan

| Bond/Interface | NICs | Purpose | VLAN | Network | HQ-PVE-01 IP |
|---|---|---|---|---|---|
| bond0 → vmbr0 | nic0 + nic4 | VMs + Management | trunk: 10, 20, 99 | 10.0.99.0/24 (on vmbr0) | 10.0.99.10 |
| bond1 | nic1 + nic5 | Ceph | 1000 (access) | 172.16.0.0/24 | 172.16.0.10 |
| bond2 | nic2 + nic6 | Migration | 1010 (access) | 172.16.1.0/24 | 172.16.1.10 |
| nic3 | nic3 | Corosync ring 0 | 1020 (access) | 172.16.2.0/24 | 172.16.2.10 |
| nic7 | nic7 | Corosync ring 1 | 1030 (access) | 172.16.3.0/24 | 172.16.3.10 |

IP assignments per host (note: you mentioned .10, .11, .13 — I'm assuming that was a typo and you mean .10, .11, .12 since they're sequential. Let me know if you really want to skip .12):

| Host | vmbr0 (mgmt) | bond1 (Ceph) | bond2 (Migration) | nic3 (Corosync R0) | nic7 (Corosync R1) |
|---|---|---|---|---|---|
| HQ-PVE-01 | 10.0.99.10 | 172.16.0.10 | 172.16.1.10 | 172.16.2.10 | 172.16.3.10 |
| HQ-PVE-02 | 10.0.99.11 | 172.16.0.11 | 172.16.1.11 | 172.16.2.11 | 172.16.3.11 |
| HQ-PVE-03 | 10.0.99.12 | 172.16.0.12 | 172.16.1.12 | 172.16.2.12 | 172.16.3.12 |

## VLAN handling note for vmbr0

Since you want the management IP directly on `vmbr0` (not on a VLAN sub-interface), the management traffic will be **untagged** on the bond. Your VMs will be assigned to VLANs 10 (server) or 20 (client) via the bridge's VLAN-aware function. So on the switch trunk:

- **Native (untagged) VLAN: 99** — this carries Proxmox management traffic
- **Tagged VLANs: 10, 20** — for VM traffic

This means switch trunks must have `switchport trunk native vlan 99` and `switchport trunk allowed vlan 10,20,99`. I'll build that into the config.

---

# Complete Updated Guide

## Phase 1: Configure HQ-CORE-STACK

### Complete switch configuration

```
configure terminal
!
! ============================================
! Global settings
! ============================================
hostname HQ-CORE-STACK
!
! Enable jumbo frames (requires reload after this)
system mtu jumbo 9000
!
! Spanning tree - rapid PVST recommended
spanning-tree mode rapid-pvst
spanning-tree extend system-id
!
! ============================================
! VLAN definitions
! ============================================
vlan 10
 name SERVER
vlan 20
 name CLIENT
vlan 99
 name MGMT
vlan 1000
 name CEPH
vlan 1010
 name MIGRATION
vlan 1020
 name COROSYNC-R0
vlan 1030
 name COROSYNC-R1
!
! ============================================
! Port-Channel interfaces - HQ-PVE-01
! ============================================
interface Port-channel10
 description HQ-PVE-01-bond0-VM-MGMT
 switchport trunk encapsulation dot1q
 switchport trunk native vlan 99
 switchport trunk allowed vlan 10,20,99
 switchport mode trunk
 spanning-tree portfast trunk
!
interface Port-channel11
 description HQ-PVE-01-bond1-CEPH
 switchport access vlan 1000
 switchport mode access
 spanning-tree portfast
 mtu 9000
!
interface Port-channel12
 description HQ-PVE-01-bond2-MIGRATION
 switchport access vlan 1010
 switchport mode access
 spanning-tree portfast
 mtu 9000
!
! ============================================
! Port-Channel interfaces - HQ-PVE-02
! ============================================
interface Port-channel20
 description HQ-PVE-02-bond0-VM-MGMT
 switchport trunk encapsulation dot1q
 switchport trunk native vlan 99
 switchport trunk allowed vlan 10,20,99
 switchport mode trunk
 spanning-tree portfast trunk
!
interface Port-channel21
 description HQ-PVE-02-bond1-CEPH
 switchport access vlan 1000
 switchport mode access
 spanning-tree portfast
 mtu 9000
!
interface Port-channel22
 description HQ-PVE-02-bond2-MIGRATION
 switchport access vlan 1010
 switchport mode access
 spanning-tree portfast
 mtu 9000
!
! ============================================
! Port-Channel interfaces - HQ-PVE-03
! ============================================
interface Port-channel30
 description HQ-PVE-03-bond0-VM-MGMT
 switchport trunk encapsulation dot1q
 switchport trunk native vlan 99
 switchport trunk allowed vlan 10,20,99
 switchport mode trunk
 spanning-tree portfast trunk
!
interface Port-channel31
 description HQ-PVE-03-bond1-CEPH
 switchport access vlan 1000
 switchport mode access
 spanning-tree portfast
 mtu 9000
!
interface Port-channel32
 description HQ-PVE-03-bond2-MIGRATION
 switchport access vlan 1010
 switchport mode access
 spanning-tree portfast
 mtu 9000
!
! ============================================
! Physical interfaces - HQ-PVE-01
! ============================================
interface range GigabitEthernet1/0/1, GigabitEthernet2/0/1
 description HQ-PVE-01-bond0
 switchport trunk encapsulation dot1q
 switchport trunk native vlan 99
 switchport trunk allowed vlan 10,20,99
 switchport mode trunk
 channel-protocol lacp
 channel-group 10 mode active
 spanning-tree portfast trunk
!
interface range GigabitEthernet1/0/2, GigabitEthernet2/0/2
 description HQ-PVE-01-bond1-CEPH
 switchport access vlan 1000
 switchport mode access
 channel-protocol lacp
 channel-group 11 mode active
 spanning-tree portfast
 mtu 9000
!
interface range GigabitEthernet1/0/3, GigabitEthernet2/0/3
 description HQ-PVE-01-bond2-MIGRATION
 switchport access vlan 1010
 switchport mode access
 channel-protocol lacp
 channel-group 12 mode active
 spanning-tree portfast
 mtu 9000
!
interface GigabitEthernet1/0/4
 description HQ-PVE-01-corosync-R0
 switchport access vlan 1020
 switchport mode access
 spanning-tree portfast
!
interface GigabitEthernet2/0/4
 description HQ-PVE-01-corosync-R1
 switchport access vlan 1030
 switchport mode access
 spanning-tree portfast
!
! ============================================
! Physical interfaces - HQ-PVE-02
! ============================================
interface range GigabitEthernet1/0/5, GigabitEthernet2/0/5
 description HQ-PVE-02-bond0
 switchport trunk encapsulation dot1q
 switchport trunk native vlan 99
 switchport trunk allowed vlan 10,20,99
 switchport mode trunk
 channel-protocol lacp
 channel-group 20 mode active
 spanning-tree portfast trunk
!
interface range GigabitEthernet1/0/6, GigabitEthernet2/0/6
 description HQ-PVE-02-bond1-CEPH
 switchport access vlan 1000
 switchport mode access
 channel-protocol lacp
 channel-group 21 mode active
 spanning-tree portfast
 mtu 9000
!
interface range GigabitEthernet1/0/7, GigabitEthernet2/0/7
 description HQ-PVE-02-bond2-MIGRATION
 switchport access vlan 1010
 switchport mode access
 channel-protocol lacp
 channel-group 22 mode active
 spanning-tree portfast
 mtu 9000
!
interface GigabitEthernet1/0/8
 description HQ-PVE-02-corosync-R0
 switchport access vlan 1020
 switchport mode access
 spanning-tree portfast
!
interface GigabitEthernet2/0/8
 description HQ-PVE-02-corosync-R1
 switchport access vlan 1030
 switchport mode access
 spanning-tree portfast
!
! ============================================
! Physical interfaces - HQ-PVE-03
! ============================================
interface range GigabitEthernet1/0/9, GigabitEthernet2/0/9
 description HQ-PVE-03-bond0
 switchport trunk encapsulation dot1q
 switchport trunk native vlan 99
 switchport trunk allowed vlan 10,20,99
 switchport mode trunk
 channel-protocol lacp
 channel-group 30 mode active
 spanning-tree portfast trunk
!
interface range GigabitEthernet1/0/10, GigabitEthernet2/0/10
 description HQ-PVE-03-bond1-CEPH
 switchport access vlan 1000
 switchport mode access
 channel-protocol lacp
 channel-group 31 mode active
 spanning-tree portfast
 mtu 9000
!
interface range GigabitEthernet1/0/11, GigabitEthernet2/0/11
 description HQ-PVE-03-bond2-MIGRATION
 switchport access vlan 1010
 switchport mode access
 channel-protocol lacp
 channel-group 32 mode active
 spanning-tree portfast
 mtu 9000
!
interface GigabitEthernet1/0/12
 description HQ-PVE-03-corosync-R0
 switchport access vlan 1020
 switchport mode access
 spanning-tree portfast
!
interface GigabitEthernet2/0/12
 description HQ-PVE-03-corosync-R1
 switchport access vlan 1030
 switchport mode access
 spanning-tree portfast
!
! ============================================
! SVI for switch management on VLAN 99
! (Adjust IP and gateway to your environment)
! ============================================
interface Vlan99
 description Management
 ip address 10.0.99.2 255.255.255.0
 no shutdown
!
ip default-gateway 10.0.99.1
!
! ============================================
! LACP system priority
! ============================================
lacp system-priority 100
!
! ============================================
! EtherChannel load balancing
! ============================================
port-channel load-balance src-dst-ip
!
end
write memory
```

> **Note about the Ceph/Migration/Corosync VLANs:** These are isolated networks with no routing. Don't create SVIs for VLAN 1000, 1010, 1020, or 1030 — they don't need to talk to anything else. If you accidentally create SVIs and someone configures a default gateway pointing to them, you've created a routing loop possibility. Keep them L2-only.

### Reload the stack to activate jumbo frames

```
reload
```

After reload, verify:

```
show system mtu
show vlan brief
show etherchannel summary
```

---

## Phase 2: Prepare Proxmox install media

Same as before — download the Proxmox VE 8.x ISO, write to a separate USB stick (not your install targets), and have your two 64GB USB drives per host ready and labeled.

---

## Phase 3: Install Proxmox on each host

### Step 3.1: Boot the installer

1. Insert both target USB drives **and** the installer USB.
2. Boot from the installer USB and select **Install Proxmox VE (Graphical)**.
3. Accept the EULA.

### Step 3.2: Disk selection

 
1. On the **Target Harddisk** screen, click **Options**.
2. Set **Filesystem** to `zfs (RAID1)` for a 2-disk mirror or `zfs (RAIDZ-1)`/mirror across 3 — for a clean 3-way mirror choose `zfs (RAID1)` and select all three disks (Proxmox treats RAID1 with 3 disks as a 3-way mirror).
3. Select **all 3 SSDs** as members.
4. Expand **Advanced Options** and set **`hdsize`** to the size you want the OS to consume — e.g., **`64`** (GB).
   > `hdsize` tells the installer to only use the first N GB of each disk for the ZFS rpool. **The remaining space on each disk is left untouched** — that free space becomes your Ceph OSD partition later. This single setting is what makes the partitioned approach work cleanly through the GUI installer.
5. Leave other ZFS options at defaults unless you have a reason to change `ashift` (default `12` = 4K is correct for SSDs).

### Step 3.3: Localization, password, network

- Country, timezone, keyboard: as appropriate.
- Root password: strong, document it.
- Email: real address for system notifications.
- Network configuration during install:
  - Management interface: **nic0**
  - Hostname: `HQ-PVE-01.prutl.internal`
  - IP/CIDR: `10.0.99.10/24`
  - Gateway: `10.0.99.1`
  - DNS: your DNS server

For HQ-PVE-02 use `.11`, for HQ-PVE-03 use `.12`.

> **Install-time networking tip:** the switch is configured for LACP on bond0 ports, which won't form with a single link. Either temporarily reconfigure one port (e.g., Gi1/0/1) to a plain access port on VLAN 99 for the install, or do the install with no switch connection and configure networking via console afterward. Restore the LACP config when ready to apply the full network setup.

### Step 3.4: Install and reboot

Let it install, remove the installer USB, reboot. You should reach `https://10.0.99.10:8006` from a machine on VLAN 99.

---

## Phase 4: Configure networking on each host

### Step 4.1: Update and install useful tools

```
apt update && apt full-upgrade -y
apt install -y ifupdown2 vim
```

### Step 4.2: Reduce writes to USB

Edit `/etc/systemd/journald.conf`:

```
[Journal]
Storage=volatile
RuntimeMaxUse=64M
SystemMaxUse=64M
```

Verify no swap:

```
swapon --show
```

Apply journald changes:

```
systemctl restart systemd-journald
```

### Step 4.3: Write the network config

Replace `/etc/network/interfaces` with the following. **Adjust the last octet for each host (.10, .11, or .12).** Example below is for HQ-PVE-01.

```
auto lo
iface lo inet loopback

# Physical interfaces
iface nic0 inet manual
iface nic1 inet manual
iface nic2 inet manual
iface nic3 inet manual
iface nic4 inet manual
iface nic5 inet manual
iface nic6 inet manual
iface nic7 inet manual

# ============================================
# bond0: VMs + Management (LACP)
# ============================================
auto bond0
iface bond0 inet manual
    bond-slaves nic0 nic4
    bond-miimon 100
    bond-mode 802.3ad
    bond-xmit-hash-policy layer2+3
    bond-lacp-rate slow

# vmbr0: VLAN-aware bridge with management IP directly on it
# Management traffic is untagged (native VLAN 99 on the switch trunk)
# VMs get assigned to VLAN 10 or 20 via their NIC config
auto vmbr0
iface vmbr0 inet static
    address 10.0.99.10/24
    gateway 10.0.99.1
    bridge-ports bond0
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094

# ============================================
# bond1: Ceph (LACP, jumbo frames)
# ============================================
auto bond1
iface bond1 inet static
    address 172.16.0.10/24
    bond-slaves nic1 nic5
    bond-miimon 100
    bond-mode 802.3ad
    bond-xmit-hash-policy layer3+4
    bond-lacp-rate slow
    mtu 9000

# ============================================
# bond2: Migration (LACP, jumbo frames)
# ============================================
auto bond2
iface bond2 inet static
    address 172.16.1.10/24
    bond-slaves nic2 nic6
    bond-miimon 100
    bond-mode 802.3ad
    bond-xmit-hash-policy layer2+3
    bond-lacp-rate slow
    mtu 9000

# ============================================
# Corosync ring 0 (nic3, stack member 1)
# ============================================
auto nic3
iface nic3 inet static
    address 172.16.2.10/24
    mtu 1500

# ============================================
# Corosync ring 1 (nic7, stack member 2)
# ============================================
auto nic7
iface nic7 inet static
    address 172.16.3.10/24
    mtu 1500
```

> **Important detail about putting the IP directly on vmbr0:** since the bridge is VLAN-aware and the IP is on the bridge itself (not a sub-interface), the management traffic is untagged on the wire. This matches the switch trunk's `native vlan 99` configuration. If you ever need to tag management instead, change the switch to remove the native VLAN and add a `vmbr0.99` sub-interface — but as configured, untagged-to-native works cleanly.

### Step 4.4: Configure /etc/hosts

```
127.0.0.1 localhost.localdomain localhost
10.0.99.10 HQ-PVE-01.prutl.internal HQ-PVE-01
10.0.99.11 HQ-PVE-02.prutl.internal HQ-PVE-02
10.0.99.12 HQ-PVE-03.prutl.internal HQ-PVE-03
```

### Step 4.5: Plug everything in and apply

Connect all 8 NICs to the switch ports per the assignment table. Restore any temporary install-time switch config back to LACP. Then:

```
ifreload -a
```

Verify:

```
ip -br addr
ip -br link
cat /proc/net/bonding/bond0
cat /proc/net/bonding/bond1
cat /proc/net/bonding/bond2
```

For each bond: "MII Status: up" on both slaves and a populated "Partner Mac Address". On the switch, `show etherchannel summary` should show all Po as `SU` with both ports `P`.

### Step 4.6: Test connectivity between all 3 hosts

After all 3 are configured, from each host:

```
# Management
ping -c 3 10.0.99.10 ; ping -c 3 10.0.99.11 ; ping -c 3 10.0.99.12

# Ceph (with jumbo frame validation)
ping -M do -s 8972 -c 3 172.16.0.10
ping -M do -s 8972 -c 3 172.16.0.11
ping -M do -s 8972 -c 3 172.16.0.12

# Migration (jumbo)
ping -M do -s 8972 -c 3 172.16.1.10
ping -M do -s 8972 -c 3 172.16.1.11
ping -M do -s 8972 -c 3 172.16.1.12

# Corosync rings
ping -c 3 172.16.2.10 ; ping -c 3 172.16.2.11 ; ping -c 3 172.16.2.12
ping -c 3 172.16.3.10 ; ping -c 3 172.16.3.11 ; ping -c 3 172.16.3.12
```

If jumbo pings fail with "frag needed", verify the switch reloaded after `system mtu jumbo 9000` and that NIC MTUs show 9000 with `ip link show bond1`.

---

## Phase 5: Configure Proxmox repos and update

On each node:

```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)"
```


---

## Phase 6: Form the cluster

### Step 6.1: Create cluster on HQ-PVE-01

```
pvecm create HQ-CLUSTER --link0 172.16.2.10 --link1 172.16.3.10
```

### Step 6.2: Join HQ-PVE-02 and HQ-PVE-03

On HQ-PVE-02:

```
pvecm add 172.16.2.10 --link0 172.16.2.11 --link1 172.16.3.11
```

On HQ-PVE-03:

```
pvecm add 172.16.2.10 --link0 172.16.2.12 --link1 172.16.3.12
```

### Step 6.3: Verify cluster and Corosync rings

```
pvecm status
corosync-cfgtool -s
```

`corosync-cfgtool -s` should show two links, both "connected".

---

## Phase 7: Install and configure Ceph

### Step 7.1: Install Ceph on all nodes

```
pveceph install --repository no-subscription
```

### Step 7.2: Initialize Ceph on HQ-PVE-01

```
pveceph init --network 172.16.0.0/24
```

### Step 7.3: Create monitors on all 3 nodes

On each node:

```
pveceph mon create
```

### Step 7.4: Create managers on all 3 nodes

On each node:

```
pveceph mgr create
```

### Step 7.5: Create OSDs on all 3 nodes

#### Step 7.5.1: Identify Disks and Free Space

On each node:
 
```bash
lsblk
ceph-volume inventory   # shows what Ceph considers usable
```

#### Step 7.5.2: Create a Partition on Each SSD, then the OSD

For **each of the 3 SSDs on each node**, create one partition spanning the free space after the rpool, then hand that partition to Ceph.
 
Example for one disk (`/dev/sdX`) — repeat per disk per node:
 
```bash
# Create one partition using all remaining free space
sgdisk -n0:0:0 -t0:8300 /dev/sdX
partprobe /dev/sdX
 
# Identify the new partition (e.g., /dev/sdX4) with lsblk, then create the OSD on it:
pveceph osd create /dev/sdX4
```
 
> `pveceph osd create` accepts a **partition** as well as a whole disk. Pointing it at the large post-OS partition is exactly how it can keep OS + OSD on the same physical SSD without conflict.
 
Repeat for all 3 SSDs on Node 1, then all 3 on Node 2, then all 3 on Node 3 → **9 OSDs total**.

### Step 7.6: Verify Ceph health

```
ceph osd tree
ceph -s
```

You want 9 OSDs all `up` and `in`, 3 monitors, 3 managers.


### Step 7.8: Create the RBD pool for VMs

#### Step 7.8.1: Create the RBD Pool for VM Disks
 
GUI: **Datacenter → \<Node> → Ceph → Pools → Create**:
 
- **Name:** `vm-pool`
- **Size:** `3`  •  **Min Size:** `2`
- **PG Autoscale:** `on` (let Ceph manage placement groups)
- Check **Add as Storage** (auto-creates the Proxmox RBD storage entry)
CLI equivalent:
 
```bash
pveceph pool create vm-pool --size 3 --min_size 2 --pg_autoscale_mode on --add_storages 1
```

This pool will appear under **Datacenter → Storage** as an RBD store usable for VM/CT disks across all nodes.

#### Step 7.8.2: Create CephFS for ISO Storage
 
ISOs (and container templates, snippets) need a **filesystem**, not raw RBD. Use CephFS.
 
1. Create the **Metadata Servers (MDS)** — at least 2 for redundancy (one active, one standby):
   GUI: **Ceph → CephFS → Create MDS** on each chosen node, or CLI on each node:
   ```bash
   pveceph mds create
   ```
 
2. Create the CephFS (this creates the data + metadata pools and mounts it cluster-wide):
   GUI: **Ceph → CephFS → Create CephFS** (name e.g., `cephfs`, check **Add as Storage**).
   CLI:
   ```bash
   pveceph fs create --name cephfs --add-storage 1
   ```
 
3. Once added as storage, edit the CephFS storage (**Datacenter → Storage → cephfs → Edit**) and enable the content types: **ISO image**, **Container template**, **Snippets**, **VZDump backup** as desired. Now ISOs uploaded there are available on every node.

---

## Phase 8: Cluster-wide settings

### Step 8.1: Configure migration network

Edit `/etc/pve/datacenter.cfg`:

```
migration: type=insecure,network=172.16.1.0/24
bwlimit: migration=500000
```

Or via the UI: Datacenter → Options → Migration Settings.

### Step 8.2: Set up HA (optional)

Datacenter → HA → Groups: create "all-nodes" with all 3 hosts. Then assign critical VMs to it.

### Step 8.3: NTP

```
systemctl status chronyd
chronyc sources
```

---

## Phase 9: Validation checklist

- [ ] `pvecm status` — 3 nodes, quorum, both Corosync rings up
- [ ] `corosync-cfgtool -s` — both links connected, no faults
- [ ] `ceph -s` — HEALTH_OK, 3 mon, 2 mgr, 9 osd up/in
- [ ] All bonds show "MII Status: up" on both slaves
- [ ] `show etherchannel summary` on switch shows all Po as SU with both ports P
- [ ] Jumbo ping works between all hosts on bond1 and bond2
- [ ] Web UI reachable at `https://10.0.99.10:8006` (and .11, .12)
- [ ] Test VM creation on Ceph storage with VLAN tag (e.g., VM NIC on vmbr0 with VLAN tag 10)
- [ ] Test live migration between hosts
- [ ] Test failover: `ip link set nic4 down` and verify bond keeps running

---

## Quick reference: assigning VMs to VLANs

Since you're putting management directly on `vmbr0` and VMs go on the same bridge, here's how to tag VMs into the right VLAN:

When creating or editing a VM's network device:
- **Bridge:** `vmbr0`
- **VLAN Tag:** `10` (for server VLAN) or `20` (for client VLAN)

The bridge handles the tagging — the VM sees a plain untagged NIC, the bond sends frames out tagged with the appropriate VLAN ID, and the switch trunk delivers them to the right VLAN.

If you want to confirm a VM's VLAN tag is working: `bridge vlan show` on the host will show which VLANs are configured on each tap interface.

---

Want me to dig into VM template setup, backup configuration, or anything else before you start the build?