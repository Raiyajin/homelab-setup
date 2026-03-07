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
  # Installer recommends at least 3GB of RAM
  memory   = 3072
  cpu_type = "host"
  cores    = 1
  sockets  = 1

  template_description = "OPNsense Golden Image"

  boot_iso {
    iso_file = "local:iso/OPNsense-26.1.2-dvd-amd64.iso"
    unmount  = true
  }

  # WAN network interface
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
  boot_wait = "60s"
  boot_command = [
    # login as installer
    "installer<enter>",
    "<wait2>opnsense<enter>",

    # Configure disk with ZFS
    "<wait5><enter>",
    "<wait2><enter>",
    "<wait2><enter>",
    "<wait2><spacebar><enter>",
    "<wait2>y",
    "<wait240>c<enter>",
    "<wait5>r<enter>",

    # wait for boot and login
    "<wait60>root<enter>",
    "<wait5>opnsense<enter>",

    # assign interfaces menu
    "<wait5>1<enter>",

    # ignore LAGG
    "<wait5><enter>",

    # ignore VLAN
    "<wait5><enter>",

    # WAN interface name
    "<wait5>vtnet0<enter>",

    # ignore LAN for now
    "<wait5><enter>",

    # ignore OPT for now
    "<wait5><enter>",

    # confirm
    "<wait5>y<enter>",

    # enter shell menu
    "<wait10>8<enter>",

    "<wait5>sed -ie 's/PermitRootLogin no/PermitRootLogin yes/' /usr/local/etc/ssh/sshd_config<enter>",
    "<wait2>sed -ie 's/PasswordAuthentication no/PasswordAuthentication yes/' /usr/local/etc/ssh/sshd_config<enter>",

    "<wait2>service openssh onerestart<enter>",

    # install os-qemu-guest-agent
    "<wait5>pkg install -y os-qemu-guest-agent<enter>",

    # enable at boot time
    "<wait5>sysrc qemu_guest_agent_enable=\"YES\"<enter>",

    # start guest agent now (ignore error)
    "<wait5>service qemu-guest-agent start || true<enter>",

    # temporarily disable the firewall
    "<wait5>pfctl -d<enter>"
  ]

  qemu_agent = true

  ssh_username = "root"
  # default opnsense password
  ssh_password = "opnsense"
  ssh_timeout  = "15m"

  tags = "opnsense;template"
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
    # force use of /bin/sh for setting env var https://developer.hashicorp.com/packer/docs/provisioners/shell#execute_command
    execute_command = "chmod +x {{ .Path }}; /bin/sh -c '{{ .Vars }} {{ .Path }}'"
    inline = [
      "mv /tmp/config.xml /conf/config.xml",
      "chown root:wheel /conf/config.xml",
      "chmod 644 /conf/config.xml"
    ]
  }
}