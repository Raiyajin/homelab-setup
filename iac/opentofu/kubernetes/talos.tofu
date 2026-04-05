# Wait for VM to be fully ready
resource "time_sleep" "wait_60_seconds" {
  depends_on = [proxmox_virtual_environment_vm.kubernetes]
  create_duration = "60s"
}

resource "talos_machine_secrets" "this" {}

data "helm_template" "cilium" {
  # TODO: add support for GatewayAPI
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  namespace  = "kube-system"
  version = "v1.19.2"
  kube_version = var.kubernetes_version

  set = [
    {
      name = "ipam.mode"
      value = "kubernetes"
    },
    # disable kube-proxy and use host IP to reach Kubernetes API
    {
        name  = "kubeProxyReplacement"
        value = "true"
    },
    {
    name  = "k8sServiceHost"
    value = "localhost"
    },
    {
      name  = "k8sServicePort"
      value = "7445"
    },
    {
      name = "securityContext.capabilities.ciliumAgent"
      value = "{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}"
    },
    {
      name = "securityContext.capabilities.cleanCiliumState"
      value = "{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}"
    },
    {
      name = "cgroup.autoMount.enabled"
      value = "false"
    },
    {
      name = "cgroup.hostRoot"
      value = "/sys/fs/cgroup"
    }
  ]
}

########################################
#             TALOS IMAGE              #
########################################

data "talos_image_factory_extensions_versions" "this" {
  for_each = {
    "base" = []
    "nvidia_gpu" = [
      "siderolabs/nvidia-container-toolkit-lts",
      "siderolabs/nvidia-open-gpu-kernel-modules-lts"
    ]
  }
  # get the latest talos version
  talos_version = var.talos_version
  filters = {
    names = concat([
      "siderolabs/qemu-guest-agent",
      "siderolabs/iscsi-tools",
    ], each.value)
  }
}

resource "talos_image_factory_schematic" "this" {
  for_each = data.talos_image_factory_extensions_versions.this
  schematic = yamlencode(
    {
      customization = {
        systemExtensions = {
          officialExtensions = each.value.extensions_info[*].name
        }
      }
    }
  )
}

data "talos_image_factory_urls" "this" {
  for_each = talos_image_factory_schematic.this
  talos_version = var.talos_version
  schematic_id  = each.value.id
  platform      = "metal"
}

########################################
#                 TALOS                #
########################################

data "talos_machine_configuration" "configuration" {
  for_each = local.vm_nodes

  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${local.bootstrapped_controlplane_ip}:6443"
  machine_type     = each.value.role
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = [
    yamlencode({
      apiVersion = "v1alpha1"
      kind = "HostnameConfig"
      hostname = each.key
      auto = "off"
    }),
    yamlencode({
    # Replace default CNI (flannel) and kube-proxy by Cilium
    cluster = {
      network = {
        cni = { name = "none" }
      }
      proxy = { disabled = true }
      inlineManifests = [
        {
          name     = "cilium"
          contents = data.helm_template.cilium.manifest
        }
      ]
    }
    
    machine = {
      install = {
        diskSelector = {
          size = "< 20GB"
        }
        image = lookup(each.value, "gpu", null) != null ? data.talos_image_factory_urls.this["nvidia_gpu"].urls.installer_secureboot : data.talos_image_factory_urls.this["base"].urls.installer_secureboot
        wipe = true
      }
      
      network = {
        # hostname = each.key
        interfaces = [
          for v in (each.value.role == "controlplane" ? [local.network_interfaces[0]] : local.network_interfaces) : {
            interface = v.interface
            dhcp = v.dhcp
            dhcpOptions = {
              routeMetric = 100
            }
          }
        ]
      }

      kernel = {
        modules = lookup(each.value, "gpu", null) != null ? [
          { name = "nvidia" },
          { name = "nvidia_uvm" },
          { name = "nvidia_drm" },
          { name = "nvidia_modeset" }
        ] : []
      }

      sysctls = {
        "net.core.bpf_jit_harden"            = 1
        "net.ipv6.conf.all.disable_ipv6"     = "1"
        "net.ipv6.conf.default.disable_ipv6" = "1"
        "net.ipv6.conf.lo.disable_ipv6"      = "1"
      }
    }
  })]
}

resource "talos_machine_configuration_apply" "apply" {
  for_each = local.vm_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.configuration[each.key].machine_configuration
  node                        = local.proxmox_vm_node_ips[each.key]
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [time_sleep.wait_60_seconds, talos_machine_configuration_apply.apply]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.bootstrapped_controlplane_ip
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.bootstrapped_controlplane_ip
}

# ########################################
# #               WORKERS                #
# ########################################

# data "talos_machine_configuration" "workers" {
#   cluster_name     = var.cluster_name
#   cluster_endpoint = "https://${local.bootstrapped_controlplane_ip}:6443"
#   machine_type     = "worker"
#   machine_secrets  = talos_machine_secrets.this.machine_secrets

#   talos_version      = var.talos_version
#   kubernetes_version = var.kubernetes_version

#   config_patches = local.config_patches
# }

# resource "talos_machine_configuration_apply" "workers" {
#   count = length(var.worker_ip_addresses)

#   client_configuration        = talos_machine_secrets.this.client_configuration
#   machine_configuration_input = data.talos_machine_configuration.workers.machine_configuration
#   node                        = var.worker_ip_addresses[count.index]

#   config_patches = local.config_patches
# }
