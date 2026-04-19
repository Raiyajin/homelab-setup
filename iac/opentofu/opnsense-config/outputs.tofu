output "subnets" {
  value = { for k, v in opnsense_kea_subnet.dhcp_subnets : k => {
    id = v.id
    cidr = v.subnet
  }}
}