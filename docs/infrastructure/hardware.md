# Hardware Specifications

This page documents the physical hardware powering my homelab.

## Cluster Nodes

| Attribute | dell-01 (Control Plane) | nuc-01 (Worker) |
|-----------|-------------------------|-----------------|
| **Hardware** | Dell Inc. OptiPlex 9020 (desktop , x86-64) | Intel corporation NUC6i5SYB (desktop , x86-64) |
| **CPU** | Intel(R) Core(TM) i7-4790 CPU @ 3.60GHz (4 cores, 8 threads) | Intel(R) Core(TM) i5-6260U CPU @ 1.80GHz (2 cores, 4 threads) |
| **Memory** | 8GB DDR3 @ 1600 MT/s (HMT351U6EFR8C-PB) - 2/4 slots used | 16GB DDR4 @ 2133 MT/s (KHX2133C13S4/8G) - 2/2 slots used |
| **Storage** | 931.5GB HDD (LVM managed, 915GB usable) | 465.8GB HDD (LVM managed, 466GB usable) |
| **Network** | Gigabit Ethernet (eno1 interface, 1500 MTU) | Gigabit Ethernet (eno1 interface, 1500 MTU) |

??? tip "Gathering Hardware Details"

    Use the automated hardware information script for consistent data collection:

    ```bash
    # Download and run the hardware info script
    wget https://raw.githubusercontent.com/jcarranz97/homelab/main/scripts/get-hardware-info.sh
    chmod +x get-hardware-info.sh
    sudo ./get-hardware-info.sh
    ```

    Or if you have the repository locally:

    ```bash
    # Run from the homelab repository
    sudo ./scripts/get-hardware-info.sh
    ```

    !!! warning "Sudo Required"
        The script requires sudo privileges to access detailed hardware information via `dmidecode`, which provides accurate memory specifications including DDR type, speed, part numbers, and slot usage.

    The script provides formatted output ready for documentation updates:

    ```bash
    root@dell-01:/home/homelab# ./get-hardware-info.sh
    Node: dell-01

    Hardware: Dell Inc. OptiPlex 9020 (desktop , x86-64)
    CPU: Intel(R) Core(TM) i7-4790 CPU @ 3.60GHz (4 cores, 8 threads)
    Memory: 8GB DDR3 @ 1600 MT/s (HMT351U6EFR8C-PB) - 2/4 slots used
    Storage: 931.5GB HDD (LVM managed, 915GB usable)
    Network: Gigabit Ethernet (eno1 interface, 1500 MTU)
    ```

## Cluster Status

Current Kubernetes cluster operational state:

| Node    | Status | Role              | Version      | OS               | Kernel         | Runtime            |
|---------|--------|-------------------|--------------|------------------|----------------|--------------------|
| dell-01 | Ready  | control-plane,master | v1.33.4+k3s1 | Ubuntu 24.04.3 LTS | 6.8.0-88-generic | containerd://2.0.5-k3s2 |
| nuc-01  | Ready  | worker            | v1.33.4+k3s1 | Ubuntu 24.04.3 LTS | 6.8.0-88-generic | containerd://2.0.5-k3s2 |

!!! tip "Real-time Cluster Status"

    Get current cluster state with: `kubectl get nodes -o wide`

## Network Equipment

### Router/Gateway

- **Model**: [Router model]
- **LAN Ports**: [Number of LAN ports]
- **Wi-Fi**: [Wi-Fi specs if applicable]
- **Features**: [Special features like VLAN support]

### Switch

- **Model**: [Switch model]
- **Ports**: [Number and type of ports]
- **Speed**: [Port speeds - e.g., Gigabit]
- **Features**: [Managed/unmanaged, VLAN support]

## Storage

### Shared Storage

- **Type**: [NAS, SAN, or local storage]
- **Capacity**: [Total storage capacity]
- **RAID Level**: [If applicable]
- **Connection**: [How it connects to cluster]

### Local Storage

- **Per Node**: [Storage per node]
- **Type**: [SSD, HDD, NVMe]
- **Purpose**: [OS, container images, logs, etc.]

## Power and Cooling

### UPS

- **Model**: [UPS model if used]
- **Capacity**: [Power capacity]
- **Runtime**: [Estimated runtime under load]

### Power Consumption

- **Idle**: [Estimated idle power consumption]
- **Under Load**: [Estimated power under load]
- **Monthly Cost**: [Estimated monthly electricity cost]

### Cooling

- **Ambient Temperature**: [Room temperature range]
- **Cooling Solution**: [Fans, AC, passive cooling]
- **Noise Level**: [Acceptable noise levels]

## Physical Setup

### Rack/Shelf

- **Type**: [Server rack, shelf, desk setup]
- **Size**: [Rack units if applicable]
- **Organization**: [How equipment is arranged]

### Cables

- **Ethernet**: [Cable types and lengths]
- **Power**: [Power cable management]
- **Organization**: [Cable management solution]

## Future Expansion Plans

### Short Term

- [ ] [Planned hardware additions]
- [ ] [Upgrades under consideration]

### Long Term

- [ ] [Future expansion ideas]
- [ ] [Technology upgrades]

## Budget Breakdown

| Component | Cost | Date Purchased | Notes |
|-----------|------|----------------|-------|
| Master Node | $XXX | YYYY-MM | [Notes] |
| Worker Node 1 | $XXX | YYYY-MM | [Notes] |
| Worker Node 2 | $XXX | YYYY-MM | [Notes] |
| Network Switch | $XXX | YYYY-MM | [Notes] |
| **Total** | **$XXXX** | | |

## Lessons Learned

### What Works Well

- [Positive experiences with hardware choices]
- [Good decisions made during setup]

### What I'd Do Differently

- [Hardware choices to reconsider]
- [Setup decisions to change]

### Recommendations

- [Advice for similar setups]
- [Vendor recommendations]

---

*Update this page whenever you make hardware changes or additions to your homelab.*
