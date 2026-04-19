
output "platform_public_key" {
  value     = tls_private_key.platform.public_key_openssh
  sensitive = true
}

output "platform_private_key" {
  value     = tls_private_key.platform.private_key_openssh
  sensitive = true
}

output "platform_hostname" {
  value = { for k, v in opnsense_unbound_host_override.override : k => "${v.hostname}.${v.domain}" }
}