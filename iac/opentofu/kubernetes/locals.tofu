locals {
  network_interfaces = {
    "controlplane" : [
      { bridge = "vmbr1", dhcp = true, interface = "ens18", vlan_id = "10" }
    ],
    "worker" : [
      { bridge = "vmbr1", dhcp = true, interface = "ens18", vlan_id = "20" },
      { bridge = "vmbr4", dhcp = true, interface = "ens19" }
    ]
  }
  tags = ["kubernetes", "talos"]
  vm_nodes = {
    "k8s-cp-01" = {
      id        = 500,
      node_name = "nas",
      cpu       = { cores = 2, sockets = 1 },
      memory    = 4096,
      role      = "controlplane"
    }
    "k8s-wk-01" = {
      id        = 550,
      node_name = "nas",
      # GPU mapping name
      gpu    = { mapping = "rtx4070" }
      cpu    = { cores = 4, sockets = 1 },
      memory = 8192,
      role   = "worker"
    }
    "k8s-wk-02" = {
      id        = 551,
      node_name = "nas",
      cpu       = { cores = 2, sockets = 1 },
      memory    = 8192,
      role      = "worker"
    }
  }

  proxmox_vm_node_ips = {
    for k, v in proxmox_virtual_environment_vm.kubernetes :
    k => element(
      v.ipv4_addresses,
      index(v.network_interface_names, local.network_interfaces["controlplane"][0].interface)
    )[0]
  }
  # bootstrapped_controlplane_ip = element(flatten(proxmox_virtual_environment_vm.kubernetes["k8s-cp-01"].ipv4_addresses), -1)
  bootstrapped_controlplane_ip = local.proxmox_vm_node_ips["k8s-cp-01"]

  kubeconfig = talos_cluster_kubeconfig.this.kubernetes_client_configuration
}