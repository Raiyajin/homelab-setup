
# resource "talos_machine_secrets" "this" {}

# ########################################
# #            CONTROLPLANE              #
# ########################################

# data "talos_machine_configuration" "controlplane" {
#   for_each = { for k, v in local.vm_nodes : k => v if v.role == "controlplane" }

#   cluster_name     = var.cluster_name
#   cluster_endpoint = "https://${proxmox_virtual_environment_vm.kubernetes[each.key].ipv4_addresses[0]}:6443"
#   machine_type     = "controlplane"
#   machine_secrets  = talos_machine_secrets.this.machine_secrets

#   talos_version      = var.talos_version
#   kubernetes_version = var.kubernetes_version

#   config_patches = local.config_patches
# }

# resource "talos_machine_configuration_apply" "controlplane" {
#   for_each = { for k, v in local.vm_nodes : k => v if v.role == "controlplane" }

#   client_configuration        = talos_machine_secrets.this.client_configuration
#   machine_configuration_input = data.talos_machine_configuration.controlplane[each.key].machine_configuration
#   node                        = proxmox_virtual_environment_vm.kubernetes[each.key].ipv4_addresses[0]

#   config_patches = local.config_patches
# }

# resource "talos_machine_bootstrap" "this" {
#   depends_on = [talos_machine_configuration_apply.controlplane]

#   client_configuration = talos_machine_secrets.this.client_configuration
#   node                 = local.bootstrapped_controlplane_ip
# }

# resource "talos_cluster_kubeconfig" "this" {
#   depends_on = [talos_machine_bootstrap.this]

#   client_configuration = talos_machine_secrets.this.client_configuration
#   node                 = local.bootstrapped_controlplane_ip
# }

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
