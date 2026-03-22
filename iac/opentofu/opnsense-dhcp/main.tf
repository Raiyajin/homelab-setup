
locals {
  dhcp_subnets = {
    "lan" : {
      "subnet_cidr" = "10.0.0.1/24"
      "pools" = [
        "10.0.0.100 - 10.0.0.200"
      ]
      description = "LAN"
    }
    "dmz" : {
      "subnet_cidr" = "10.0.10.1/24"
      "pools" = [
        "10.0.10.100 - 10.0.10.200"
      ]
      description = "DMZ"
    }
    "pc_isolated" : {
      "subnet_cidr" = "10.0.20.1/24"
      "pools" = [
        "10.0.20.100 - 10.0.20.200"
      ]
      description = "PC"
    }
  }
}

resource "opnsense_kea_subnet" "dhcp_subnets" {
  for_each = local.dhcp_subnets

  dns_servers = [
    "10.0.0.1",
  ]
  ntp_servers = [
    "10.0.0.1"
  ]
  routers = [
    "10.0.0.1"
  ]

  match_client_id = false

  subnet = each.value.subnet_cidr
  pools  = each.value.pools

  description = each.value.description
}

