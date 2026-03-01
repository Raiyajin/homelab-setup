# Homelab Setup

## 🚀 Home Lab Node 01 - Self-built NAS

### 🏗️ Core System: CWWK Ryzen 8845HS
* Processor: AMD Ryzen 7 8845HS (8 Cores, 16 Threads) @ 5.1GHz Boost
* Graphics: Integrated Radeon 780M
* Networking: 4x Intel i226-V 2.5GbE Controllers (RJ45)
 
### 📦 Case & Storage: Fractal Node 804
* Case: Fractal Design Node 804 (Dual-chamber Micro-ATX design)
* Total Capacity: ~26TB (Target)
* Drive Configuration: * Boot/OS: NVMe SSD
* Storage Pool: High-capacity SATA HDDs
* Cooling: Optimized for quiet, high-density storage airflow

### 🔌 Network Infrastructure
* Router: Freebox Pop
* Primary Switch: TP-Link Unmanaged 8-Port 2.5G (TL-SG108-M2)

### 🌐 Logical Network Mapping
|Physical Port|Interface (OS)|Color |Assignment        |Destination      |
|-------------|--------------|------|------------------|-----------------|
|Port 1       |enp4s0        |Blue  |WAN / Proxmox MGMT|ISP Router (1G)  |
|Port 2       |enp5s0        |Yellow|LAN (High Speed)  |2.5G Switch      |
|Port 3       |enp6s0        |Red   |DMZ / Guest       |2.5G Switch      |
|Port 4       |enp7s0        |Black |Direct Link / PC  |Workstation PC   |

### 🛠️ Software Stack
* Hypervisor: Proxmox VE (Debian-based)
* Firewall/Routing: OPNsense
* Automation: OpenTofu (via OPNsense & Proxmox Providers)

## Schema
![homelab-setup](/documentation/images/homelab-setup.drawio.png)