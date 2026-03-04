locals {
  linux_bridges = {
    # This bridge exist already as it was initialized for setting up proxmox
    vmbr0 = { ports = ["enp4s0"], mac_address = "BC:24:11:AA:BB:01", managed = false }
    vmbr1 = { ports = ["enp5s0"], mac_address = "BC:24:11:AA:BB:02", managed = true  }
    vmbr2 = { ports = ["enp6s0"], mac_address = "BC:24:11:AA:BB:03", managed = true  }
    vmbr3 = { ports = ["enp7s0"], mac_address = "BC:24:11:AA:BB:04", managed = true  }
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

  # Config Importer
  disk {
    datastore_id = "local"
    interface    = "scsi1"
    file_id      = proxmox_virtual_environment_file.config_disk_img.id
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

# # We use a map to define our nodes
# locals {
#   nodes = {
#     "k8s-cp-01"   = { id = 500, cpu = 2, mem = 4096 }
#     "k8s-wk-01"   = { id = 501, cpu = 4, mem = 8192 }
#     "k8s-wk-02"   = { id = 502, cpu = 4, mem = 8192 }
#   }
# }

# resource "proxmox_virtual_environment_vm" "k8s_nodes" {
#   for_each  = local.nodes
#   name      = each.key
#   node_name = "nas"
#   vm_id     = each.value.id

#   cpu { cores = each.value.cpu, type = "x86-64-v4" }
#   memory { dedicated = each.value.mem }

#   # K8s nodes sit in the DMZ bridge for MetalLB access
#   network_device {
#     bridge = "vmbr2"
#   }

#   # For K8s, Cloud-Init IS your friend.
#   initialization {
#     ip_config {
#       ipv4 {
#         address = "dhcp"
#       }
#     }
#   }
# }