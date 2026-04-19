locals {
  services = {
    openbao = {
      vm_id = 200
      # Host on the PLATFORM Subnet
      cidr_host = "10"
      disk = {
        datastore_id = "local-lvm"
        size         = 10
      }
      network_interface = {
        name        = "eth0"
        bridge      = "vmbr1"
        vlan_id     = 5
        mac_address = "BC:24:11:AA:BC:00"
      }
    }
  }
}

resource "proxmox_virtual_environment_container" "container" {
  for_each = local.services

  description = "Managed by Terraform"

  node_name = var.node_name
  vm_id     = each.value.vm_id

  unprivileged = true
  features {
    nesting = true
  }

  wait_for_ip {
    ipv4 = true
  }

  initialization {
    hostname = each.key

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      keys = [
        trimspace(tls_private_key.platform.public_key_openssh)
      ]
    }
  }

  network_interface {
    name        = each.value.network_interface.name
    bridge      = each.value.network_interface.bridge
    vlan_id     = each.value.network_interface.vlan_id
    mac_address = each.value.network_interface.mac_address
  }

  disk {
    datastore_id = each.value.disk.datastore_id
    size         = each.value.disk.size
  }

  operating_system {
    template_file_id = proxmox_download_file.debian.id
    type = "debian"
  }

  startup {
    order      = "2"
    up_delay   = "10"
    down_delay = "10"
  }

  tags = [each.key, "platform"]
}


resource "proxmox_download_file" "debian" {
  node_name           = var.node_name
  content_type        = "vztmpl"
  datastore_id        = "local"
  url                 = "http://download.proxmox.com/images/system/debian-13-standard_13.1-2_amd64.tar.zst"
  overwrite           = false
  overwrite_unmanaged = false
}

resource "tls_private_key" "platform" {
  algorithm = "ED25519"
}

resource "opnsense_kea_reservation" "static_ip" {
  for_each = local.services

  subnet_id = data.terraform_remote_state.opnsense.outputs.subnets["platform"].id

  ip_address  = cidrhost(data.terraform_remote_state.opnsense.outputs.subnets["platform"].cidr, each.value.cidr_host)
  mac_address = each.value.network_interface.mac_address

  description = "Static IP for ${each.key}"
}

resource "opnsense_unbound_host_override" "override" {
  for_each = local.services

  enabled = true
  description = "Domain override for ${each.key}"

  hostname = each.key
  domain = "internal"

  type = "A"
  server = opnsense_kea_reservation.static_ip[each.key].ip_address
}