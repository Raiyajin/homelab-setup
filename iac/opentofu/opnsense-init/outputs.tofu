output "network_devices" {
  value = proxmox_virtual_environment_vm.opnsense.network_device[*]
}