resource "proxmox_virtual_environment_storage_lvmthin" "kubernetes" {
  id    = "kubernetes"
  nodes = ["nas"]

  volume_group = "hdd01"
  thin_pool    = "hdd01"

  content = ["images"]
}

resource "proxmox_virtual_environment_download_file" "talos_boot_image" {
  node_name = "nas"

  content_type = "iso"
  datastore_id = "local"

  url       = data.talos_image_factory_urls.this["base"].urls.iso_secureboot
  file_name = "metal-amd64-secureboot.iso"
}

resource "proxmox_virtual_environment_vm" "kubernetes" {
  for_each  = local.vm_nodes
  name      = each.key
  node_name = each.value.node_name
  vm_id     = each.value.id

  agent {
    enabled = true
    wait_for_ip {
      ipv4 = true
    }
  }

  boot_order = ["scsi0", "ide3"]

  startup {
    order = "2"
    # Wait time before starting/shutting down next VMs
    up_delay   = "15"
    down_delay = "15"
  }

  # GPU passthrough related parameters (see: https://pve.proxmox.com/wiki/PCI(e)_Passthrough)
  bios    = "ovmf"
  machine = "q35"

  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    type         = "4m"
  }

  dynamic "hostpci" {
    for_each = lookup(each.value, "gpu", {})
    content {
      device  = "hostpci0"
      mapping = hostpci.value
      pcie    = true
      xvga    = false
      rombar  = true
    }
  }

  cpu {
    cores   = each.value.cpu.cores
    sockets = each.value.cpu.sockets
    type    = "x86-64-v4"

    flags = [
      # 1GB Hugepages
      "+pdpe1gb",
      # Hardware Encryption
      "+aes",
      # Speculative Store Bypass Disable
      "+virt-ssbd"
    ]
  }
  memory {
    dedicated = each.value.memory
  }

  dynamic "network_device" {
    for_each = local.network_interfaces[each.value.role]

    content {
      bridge  = network_device.value.bridge
      vlan_id = lookup(network_device.value, "vlan_id", null)

      model    = "virtio"
      firewall = false
    }
  }

  scsi_hardware = "virtio-scsi-single"

  dynamic "disk" {
    for_each = merge({
      # Talos OS Drive (followed minimum recommandation from: https://docs.siderolabs.com/talos/v1.9/getting-started/system-requirements) 
      scsi0 = {
        datastore_id = "local-lvm"
        size = 10
        ssd = true
      }
    },
    each.value.role == "worker" ? {
      scsi1 =  {
        datastore_id = proxmox_virtual_environment_storage_lvmthin.kubernetes.id
        size = 5000
        ssd = false
      }
    } : {})
    content {
      datastore_id = disk.value.datastore_id
      size         = disk.value.size
      interface    = disk.key
      file_format  = "raw"
      ssd          = disk.value.ssd
      iothread     = true      
    }
  }

  # Attachment for the Installer ISO
  cdrom {
    file_id   = proxmox_virtual_environment_download_file.talos_boot_image.id
    interface = "ide3"
  }

  operating_system {
    # Linux Kernel 2.6 - 5.X.
    type = "l26"
  }

  tags = concat(local.tags, [each.value.role])
}