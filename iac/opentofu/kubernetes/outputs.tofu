output "controlplane_ips" {
  value = proxmox_virtual_environment_vm.kubernetes["k8s-cp-01"].ipv4_addresses
}

output "bootstrapped_controlplane_ips" {
  value = local.bootstrapped_controlplane_ip
}

output "kubeconfig" {
  value     = local.kubeconfig
  sensitive = true
}

output "talosconfig" {
  value     = talos_cluster_kubeconfig.this.client_configuration
  sensitive = true
}

output "talos_installer_urls" {
  value = { for k, v in data.talos_image_factory_urls.this : k => v.urls.installer_secureboot }
}

output "talos_boot_image" {
  value = proxmox_virtual_environment_download_file.talos_boot_image
}

output "proxmox_node_disks" {
  value = { for k, v in proxmox_virtual_environment_vm.kubernetes : k => v.disk }

}