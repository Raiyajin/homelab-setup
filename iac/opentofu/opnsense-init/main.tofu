locals {
  linux_bridges = {
    # This bridge exist already as it was initialized for setting up proxmox
    vmbr0  = { ports = ["enp4s0"], mac_address = "BC:24:11:AA:BB:01", managed = false }
    vmbr1  = { ports = ["enp5s0"], mac_address = "BC:24:11:AA:BB:02", managed = true, vlan_aware = true }
    vmbr2  = { ports = ["enp6s0"], mac_address = "BC:24:11:AA:BB:03", managed = true, vlan_aware = true }
    vmbr3  = { ports = ["enp7s0"], mac_address = "BC:24:11:AA:BB:04", managed = true }
    vmbr4 = { ports = [], mac_address = "BC:24:11:AA:BB:05", managed = true }
  }
  linux_vlans = {
    K8S_CP      = { id = 10, interface = "vmbr1" }
    K8S_WK      = { id = 20, interface = "vmbr1" }
    WIFI_SECURE = { id = 30, interface = "vmbr2" }
    WIFI_GUEST  = { id = 40, interface = "vmbr2" }
  }
  trunks = {
    for name, config in local.linux_vlans : config.interface => config.id...
  }
}

resource "proxmox_virtual_environment_network_linux_bridge" "linux_bridge" {
  for_each  = { for k, v in local.linux_bridges : k => v if v.managed }
  node_name = var.proxmox_node
  name      = each.key
  ports     = each.value.ports

  vlan_aware = lookup(each.value, "vlan_aware", false)
}

resource "proxmox_virtual_environment_network_linux_vlan" "linux_vlan" {
  for_each  = local.linux_vlans
  node_name = var.proxmox_node
  name      = each.key

  interface = each.value.interface
  vlan      = each.value.id
}

resource "proxmox_virtual_environment_vm" "opnsense" {
  name      = "opnsense"
  node_name = var.proxmox_node
  vm_id     = 100

  clone {
    full  = true
    vm_id = var.opnsense_template_id
  }

  agent { enabled = true }

  startup {
    order = "1"
    # Wait time before starting/shutting down next VMs
    up_delay   = "60"
    down_delay = "60"
  }

  cpu {
    cores   = 2
    sockets = 1
    # enable cpu hardware acceleration
    type  = "host"
    flags = ["+aes"]
  }
  memory {
    dedicated = 4096
  }

  # Network interfaces
  dynamic "network_device" {
    for_each = local.linux_bridges
    content {
      bridge      = network_device.key
      mac_address = network_device.value.mac_address
      model       = "virtio"

      trunks = join(";", lookup(local.trunks, network_device.key, []))
    }
  }

  scsi_hardware = "virtio-scsi-single"

  # OS Drive
  disk {
    datastore_id = "local-lvm"
    size         = 32
    interface    = "scsi0"
    file_format  = "raw"
    ssd          = true
    iothread     = true
  }

  # Attachment for the Installer ISO
  cdrom {
    file_id = "local:iso/OPNsense-${var.opnsense_version}-dvd-amd64.iso"
  }

  operating_system {
    # Linux Kernel 2.6 - 5.X.
    type = "l26"
  }

  tags = var.default_tags
}
