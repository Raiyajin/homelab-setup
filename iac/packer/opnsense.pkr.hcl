packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "opnsense_builder" {
  # Proxmox Connection
  node                     = "nas"
  insecure_skip_tls_verify = true

  # VM Specs for the build
  vm_name = "opnsense-template"
  vm_id   = 10000
  # Installer requires at least 3GB of RAM
  memory   = 3072
  cpu_type = "host"
  cores    = 1
  sockets  = 1

  template_description = "OPNsense Golden Image"

  boot_iso {
    iso_file = "local:iso/OPNsense-26.1.2-dvd-amd64.iso"
    unmount  = true
  }

  # Build Hardware (Single NIC only)
  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  disks {
    disk_size    = "20G"
    storage_pool = "local-lvm"
    type         = "scsi"
  }

  # BSD Installer Automation (Keystrokes)
  boot_wait = "10s"
  boot_command = [
    "installer<enter>",
    "<wait5><enter>",           # Select Keymap
    "<wait2><down><enter>",     # Select Install (ZFS)
    "<wait2><enter>",           # Stripe
    "<wait2><spacebar><enter>", # Select Disk
    "<wait2>y",                 # Confirm Destruction
    "<wait120>reboot<enter>"    # Wait for install then reboot
  ]

  ssh_username = "root"
  # default opnsense password
  ssh_password = "opnsense"
  ssh_timeout  = "15m"
}

build {
  sources = ["source.proxmox-iso.opnsense_builder"]

  # Upload the config.xml into the VM
  provisioner "file" {
    source      = "config.xml"
    destination = "/tmp/config.xml"
  }

  # Move the config to the correct location and reload
  provisioner "shell" {
    inline = [
      "mv /tmp/config.xml /conf/config.xml",
      "chown root:wheel /conf/config.xml",
      "chmod 644 /conf/config.xml"
    ]
  }
}