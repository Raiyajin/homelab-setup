# Wait for VM to be fully ready
resource "time_sleep" "wait_60_seconds" {
  depends_on      = [proxmox_virtual_environment_vm.kubernetes]
  create_duration = "60s"
}

resource "talos_machine_secrets" "this" {}

data "helm_template" "cilium" {
  name         = "cilium"
  repository   = "https://helm.cilium.io/"
  chart        = "cilium"
  namespace    = "kube-system"
  version      = "v1.19.2"
  kube_version = var.kubernetes_version

  values = [
    <<-EOT
  ipam:
    mode: kubernetes

  kubeProxyReplacement: true
  k8sServiceHost: localhost
  k8sServicePort: 7445
  
  securityContext:
    capabilities:
      ciliumAgent:
        - BPF
        - CHOWN
        - KILL
        - NET_ADMIN
        - NET_RAW
        - IPC_LOCK
        - SYS_ADMIN
        - SYS_RESOURCE
        - DAC_OVERRIDE
        - FOWNER
        - SETGID
        - SETUID
      cleanCiliumState: 
        - NET_ADMIN
        - SYS_ADMIN
        - SYS_RESOURCE
  cgroup:
    autoMount: 
      enabled: false
    hostRoot: "/sys/fs/cgroup"

  gatewayAPI:
    enabled: true
    hostNetwork:
      enabled: false

  l2announcements:
    enabled: true
  EOT
  ]
}

data "helm_template" "argocd" {
  name         = "argo-cd"
  repository   = "https://argoproj.github.io/argo-helm/"
  chart        = "argo-cd"
  namespace    = "argocd"
  version      = "9.4.17"
  kube_version = var.kubernetes_version

  set = [
    { name  = "global.domain"
      value = "argocd.homelab.internal"
    },
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
  for_each      = talos_image_factory_schematic.this
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
      kind       = "HostnameConfig"
      hostname   = each.key
      auto       = "off"
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
          },
          {
            name     = "argocd"
            contents = <<-EOT
          apiVersion: v1
          kind: Namespace
          metadata:
            name: ${data.helm_template.argocd.namespace}
          spec: {}
          status: {}
          ---
          ${data.helm_template.argocd.manifest}
          ---
          apiVersion: v1
          kind: Secret
          type: Opaque
          metadata:
            annotations:
              managed-by: argocd.argoproj.io
            labels:
              argocd.argoproj.io/secret-type: repository
            name: repo-github-homelab-setup
            namespace: argocd
          data:
            project: ${base64encode("default")}
            type: ${base64encode("git")}
            url: ${base64encode(var.github_repository)}
          ---
          apiVersion: v1
          metadata:
            name: internal-ca
            namespace: kube-system
          data:
            cert: ${var.base64_internal_ca}
          kind: Secret
          type: Opaque
          EOT
          }
        ]
      }

      machine = {
        nodeLabels = merge([
          for disk in proxmox_virtual_environment_vm.kubernetes[each.key].disk : {
            for filter in ["datastore_id", "ssd", "size"] :
            "proxmox.com/disk.${disk.interface}-${replace(filter, "_", "-")}" => tostring(lookup(disk, filter, ""))
          }
        ]...)
        install = {
          diskSelector = {
            size = "< 120GB"
          }
          image = lookup(each.value, "gpu", null) != null ? data.talos_image_factory_urls.this["nvidia_gpu"].urls.installer_secureboot : data.talos_image_factory_urls.this["base"].urls.installer_secureboot
          wipe  = true
        }

        disks = each.value.role == "worker" ? [
          {
            device = "/dev/sdb"
            partitions = [
              {
                mountpoint = "/var/mnt/storage"
              }
            ]
          }
        ] : []

        network = {
          interfaces = [
            for v in local.network_interfaces[each.value.role] : {
              interface = v.interface
              dhcp      = v.dhcp
              dhcpOptions = v.dhcp ? {
                routeMetric = 100
              } : null
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
        files = lookup(each.value, "gpu", null) != null ? [
          {
            content     = <<-EOT
            [plugins]
              [plugins."io.containerd.grpc.v1.cri"]
                [plugins."io.containerd.grpc.v1.cri".containerd]
                  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
                    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
                      privileged_without_host_devices = false
                      runtime_type = "io.containerd.runc.v2"
                      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
                        BinaryName = "/usr/local/bin/nvidia-container-runtime"
          EOT
            path        = "/var/cri/conf.d/20-nvidia.toml"
            op          = "create"
            permissions = 0
          }
        ] : []

        sysctls = {
          "net.core.bpf_jit_harden"            = "1"
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
