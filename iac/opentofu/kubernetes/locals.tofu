locals {
  network_interfaces = {
    # LAN interface
    vmbr1 = { mac_address = "BC:24:11:AA:BB:02", dhcp = true }
    # DMZ interface - static IPs only
    vmbr2 = { mac_address = "BC:24:11:AA:BB:03", dhcp = false }
  }
  tags = ["kubernetes", "talos"]
  vm_nodes = {
    "k8s-cp-01" = {
      id        = 500,
      node_name = "nas",
      cpu       = { cores = 2, sockets = 1 },
      mem       = 4096,
      role      = "controlplane"
    }
    # "k8s-wk-01" = {
    #   id        = 550,
    #   node_name = "nas",
    #   # GPU mapping name
    #   gpu  = { mapping = "rtx4070" }
    #   cpu  = { cores = 4, sockets = 1 },
    #   mem  = 8192,
    #   role = "worker"
    # }
    # "k8s-wk-02" = {
    #   id        = 551,
    #   node_name = "nas",
    #   cpu       = { cores = 2, sockets = 1 },
    #   mem       = 8192,
    #   role      = "worker"
    # }
  }
  config_patches = [yamlencode({
    # Remove default CNI (flannel) and kube-proxy
    cluster = {
      network = {
        cni = { name = "none" }
      }
      proxy = { disabled = true }
    }
    machine = {
      install = {
        disk  = "/dev/vda"
        image = var.talos_install_image
      }
      network = {
        interfaces = [
          for k, v in local.network_interfaces : {
            deviceSelector = {
              driver = "virtio", hardwareAddr = v.mac_address
            }
            dhcp = v.dhcp
          }
        ]
      }
      kernel = {
        modules = [
          { name = "nvidia" },
          { name = "nvidia_uvm" },
          { name = "nvidia_drm" },
          { name = "nvidia_modeset" }
        ]
        extraKernelArgs = [
          "nouveau.modeset=0"
        ]
      }
      sysctls = {
        "net.core.bpf_jit_harden"            = 1
        "net.ipv6.conf.all.disable_ipv6"     = "1"
        "net.ipv6.conf.default.disable_ipv6" = "1"
        "net.ipv6.conf.lo.disable_ipv6"      = "1"
      }
    }
  })]

  bootstrapped_controlplane_ip = flatten(proxmox_virtual_environment_vm.kubernetes["k8s-cp-01"].ipv4_addresses)
}