locals {
  linux_bridges = {
    # This bridge exist already as it was initialized for setting up proxmox
    vmbr0 = { ports = ["enp4s0"], mac_address = "BC:24:11:AA:BB:01", managed = false }
    vmbr1 = { ports = ["enp5s0"], mac_address = "BC:24:11:AA:BB:02", managed = true  }
    vmbr2 = { ports = ["enp6s0"], mac_address = "BC:24:11:AA:BB:03", managed = true  }  
  }
}

resource "proxmox_virtual_environment_network_linux_bridge" "linux_bridge" {
  for_each = { for k, v in local.linux_bridges : k => v if v.managed }
  node_name = "nas"
  name      = each.key
  ports     = each.value.ports
}

resource "proxmox_virtual_environment_vm" "opnsense" {
  name      = "opnsense"
  node_name = "nas"
  vm_id     = 100

  agent { enabled = true }

  startup {
    order      = "1"
    # Wait time before starting/shutting down next VMs
    up_delay   = "60"
    down_delay = "60"
  }

  cpu { 
    cores = 2
    # enable cpu hardware acceleration
    type = "host"
    flags = ["+aes"]
  }
  memory { 
    dedicated = 4096 
  }

  # Network interfaces
  dynamic "network_device" { 
    for_each = local.linux_bridges
    content {
      bridge = network_device.key
      mac_address = network_device.value.mac_address
      model       = "virtio"
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
    file_id   = "local:iso/OPNsense-26.1.2-dvd-amd64.iso"
  }

  operating_system {
    # Linux Kernel 2.6 - 5.X.
    type = "l26"
  }
}
