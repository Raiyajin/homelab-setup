
locals {
  dhcp_subnets = {
    "lan": {
      subnet_cidr = "10.0.0.0/24"
      pools = [
        "10.0.0.100 - 10.0.0.200"
      ]
      description = "LAN"
      interface = "lan"
    }
    "dmz": {
      subnet_cidr = "10.0.10.0/24"
      pools = [
        "10.0.10.100 - 10.0.10.200"
      ]
      description = "DMZ"
      interface = "opt1"

    }
    "pc_isolated": {
      subnet_cidr = "10.0.20.0/24"
      pools = [
        "10.0.20.100 - 10.0.20.200"
      ]
      description = "PC"
      interface = "opt2"
    }
    "wireguard": {
      subnet_cidr = "10.1.0.0/24"
      description = "WireGuard (Group)"
      interface = "wireguard"
    }
  }
}

resource "opnsense_kea_subnet" "dhcp_subnets" {
  for_each = { for k, v in local.dhcp_subnets : k => v if lookup(v, "pools", null) != null }

  auto_collect = false

  dns_servers = [
    # First IP of the subnet which correspond to opnsense
    cidrhost(each.value.subnet_cidr, 1),
  ]
  ntp_servers = [
    cidrhost(each.value.subnet_cidr, 1)
  ]
  routers = [
    cidrhost(each.value.subnet_cidr, 1)
  ]

  domain_name = "internal"

  domain_search = [
    "internal",
  ]

  match_client_id = false

  subnet = each.value.subnet_cidr
  pools  = each.value.pools

  description = each.value.description
}

resource "opnsense_firewall_filter" "dmz" {
  for_each = {
    "ntp" = { protocol = "UDP", port = 123 }
    "dns" = { protocol = "TCP/UDP", port = 53 }
  }
  enabled     = true
  description = "Allow ${upper(each.key)} traffic to opnsense server"

  interface = {
    interface = [local.dhcp_subnets["dmz"].interface]
  }

  filter = {
    quick     = true
    action    = "pass"
    direction = "in"
    protocol  = each.value.protocol

    source = {
      net = local.dhcp_subnets["dmz"].subnet_cidr
    }

    destination = {
      net  = "${cidrhost(local.dhcp_subnets["dmz"].subnet_cidr, 1)}/32",
      port = each.value.port
    }

    log = false
  }
}  

resource "opnsense_firewall_filter" "wireguard" {
  for_each = {
    "talos_apid" = { protocol = "TCP", port = 50000 }
    "talos_trustd" = { protocol = "TCP", port = 50001 }
    "talos_https" = { protocol = "TCP", port = 6443 }
  }
  enabled     = true
  description = "Allow ${upper(each.key)} traffic to opnsense server"

  interface = {
    interface = [local.dhcp_subnets["wireguard"].interface]
  }

  filter = {
    quick     = true
    action    = "pass"
    direction = "in"
    protocol  = each.value.protocol

    source = {
      net = local.dhcp_subnets["wireguard"].subnet_cidr
    }

    destination = {
      net  = local.dhcp_subnets["lan"].subnet_cidr
      port = each.value.port
    }

    log = false
  }
}  
