
locals {
  dhcp_subnets = {
    "lan" : {
      subnet_cidr = "10.0.0.0/24"
      pools = [
        "10.0.0.100 - 10.0.0.200"
      ]
      description = "LAN"
      interface   = "lan"
    }
    "dmz" : {
      subnet_cidr = "10.0.10.0/24"
      pools = [
        "10.0.10.100 - 10.0.10.200"
      ]
      description = "DMZ"
      interface   = "opt1"

    }
    "pc_isolated" : {
      subnet_cidr = "10.0.20.0/24"
      pools = [
        "10.0.20.100 - 10.0.20.200"
      ]
      description = "PC"
      interface   = "opt2"
    }
    "wireguard" : {
      subnet_cidr = "10.1.0.0/24"
      description = "WireGuard (Group)"
      interface   = "wireguard"
    }
    "wifi_secure" : {
      subnet_cidr = "10.10.0.0/24"
      pools = [
        "10.10.0.100 - 10.10.0.200"
      ]
      description = "Wifi Secure"
      interface   = "opt8"
    }
    "wifi_guest" : {
      subnet_cidr = "10.10.10.0/24"
      pools = [
        "10.10.10.100 - 10.10.10.200"
      ]
      description = "Wifi Guest"
      interface   = "opt7"
    }
    "k8s_cp" : {
      subnet_cidr = "10.20.0.0/24"
      pools = [
        "10.20.0.100 - 10.20.0.200"
      ]
      description = "Kubernetes Control Plane"
      interface   = "opt6"
    }
    "k8s_wk" : {
      subnet_cidr = "10.20.10.0/24"
      pools = [
        "10.20.10.100 - 10.20.10.200"
      ]
      description = "Kubernetes Worker"
      interface   = "opt5"
    }
    "insecure" : {
      subnet_cidr = "10.50.0.0/24"
      pools = [
        "10.50.0.100 - 10.50.0.200"
      ]
      description = "Insecure"
      interface   = "opt4"
    }
    "platform" : {
      subnet_cidr = "10.20.5.0/24"
      pools = [
        "10.20.5.100 - 10.20.5.200"
      ]
      description = "Platform"
      interface   = "opt9"
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

resource "opnsense_firewall_category" "category" {
  for_each = toset([
    "baseline",
    "talos"
  ])
  name = each.value
}

resource "opnsense_firewall_filter" "ntp" {
  for_each = { for k, v in local.dhcp_subnets : k => v if v.interface != "wireguard" }

  enabled     = true
  description = "Allow NTP traffic"

  interface = {
    interface = [each.value.interface]
  }

  categories = [
    opnsense_firewall_category.category["baseline"].id
  ]

  filter = {
    quick     = true
    action    = "pass"
    direction = "in"
    protocol  = "UDP"

    source = {
      net = "${each.value.interface}"
    }

    destination = {
      net  = "${each.value.interface}ip"
      port = 123
    }

    log = false
  }
}

resource "opnsense_firewall_filter" "dns" {
  for_each = { for k, v in local.dhcp_subnets : k => v if v.interface != "wireguard" }

  enabled     = true
  description = "Allow DNS traffic"

  interface = {
    interface = [each.value.interface]
  }

  categories = [
    opnsense_firewall_category.category["baseline"].id
  ]

  filter = {
    quick     = true
    action    = "pass"
    direction = "in"
    protocol  = "TCP/UDP"

    source = {
      net = "${each.value.interface}"
    }

    destination = {
      net  = "${each.value.interface}ip"
      port = 53
    }

    log = false
  }
}

resource "opnsense_firewall_filter" "public" {
  for_each = {
    "http" = { protocol = "TCP", port = 80 }
    "https" = { protocol = "TCP", port = 443 }
    "ping" = { protocol = "ICMP", port = null }
  }
  enabled     = true
  description = "Allow ${upper(each.key)} traffic"

  # All interface but INSECURE
  interface = {
    invert = true
    interface = [local.dhcp_subnets["insecure"].interface]
  }

  categories = [
    opnsense_firewall_category.category["baseline"].id
  ]

  filter = {
    quick     = true
    action    = "pass"
    direction = "in"
    protocol  = each.value.protocol

    source = {
      net = "any"
    }

    destination = {
      net  = "any"
      port = each.value.port
    }

    log = false
  }
}

resource "opnsense_firewall_filter" "platform_controlplane" {
  for_each = {
    "k8s_api"  = { protocol = "TCP", port = 6443 }
  }
  enabled     = true
  description = "Allow ${each.key} from platform to k8s controlplane"

  interface = {
    interface = [
      local.dhcp_subnets["platform"].interface,
    ]
  }

  categories = [
    opnsense_firewall_category.category["talos"].id
  ]

  filter = {
    quick     = true
    action    = "pass"
    direction = "in"
    protocol  = each.value.protocol

    source = {
      net = local.dhcp_subnets["platform"].interface
    }

    destination = {
      net  = local.dhcp_subnets["k8s_cp"].interface
      port = each.value.port
    }

    log = true
  }
}

resource "opnsense_firewall_filter" "wireguard_controlplane" {
  for_each = {
    "talos_apid"   = { protocol = "TCP", port = 50000 }
    # "talos_trustd" = { protocol = "TCP", port = 50001 }
    "k8s_api"  = { protocol = "TCP", port = 6443 }
  }
  enabled     = true
  description = "Allow ${each.key} from wireguard to k8s controlplane"

  interface = {
    interface = [
      local.dhcp_subnets["wireguard"].interface,
    ]
  }

  categories = [
    opnsense_firewall_category.category["talos"].id
  ]

  filter = {
    quick     = true
    action    = "pass"
    direction = "in"
    protocol  = each.value.protocol

    source = {
      net = local.dhcp_subnets["wireguard"].interface
    }

    destination = {
      net  = local.dhcp_subnets["k8s_cp"].interface
      port = each.value.port
    }

    log = true
  }
}

resource "opnsense_firewall_filter" "wireguard_worker" {
  for_each = {
    "talos_apid"   = { protocol = "TCP", port = 50000 }
  }
  enabled     = true
  description = "Allow ${each.key} from wireguard to k8s workers"

  interface = {
    interface = [
      local.dhcp_subnets["wireguard"].interface,
    ]
  }

  categories = [
    opnsense_firewall_category.category["talos"].id
  ]

  filter = {
    quick     = true
    action    = "pass"
    direction = "in"
    protocol  = each.value.protocol

    source = {
      net = local.dhcp_subnets["wireguard"].interface
    }

    destination = {
      net  = local.dhcp_subnets["k8s_wk"].interface
      port = each.value.port
    }

    log = false
  }
}

resource "opnsense_firewall_filter" "wireguard_platform" {
  for_each = {
    "ssh"   = { protocol = "TCP", port = 22 }
  }
  enabled     = true
  description = "Allow ${each.key} from wireguard to platform"

  interface = {
    interface = [
      local.dhcp_subnets["wireguard"].interface,
    ]
  }

  filter = {
    quick     = true
    action    = "pass"
    direction = "in"
    protocol  = each.value.protocol

    source = {
      net = local.dhcp_subnets["wireguard"].interface
    }

    destination = {
      net  = local.dhcp_subnets["platform"].interface
      port = each.value.port
    }

    log = false
  }
}

resource "opnsense_firewall_filter" "controlplane_worker" {
  for_each = {
    "talos_apid"   = { protocol = "TCP", port = 50000 }
    "kubelet_api" = { protocol = "TCP", port = 10250 }
    "cilium_vxlan" = { protocol = "UDP", port = 8472 }
    "cilium_health" = { protocol = "TCP", port = 4240 }
    "cilium_hubble" = { protocol = "TCP", port = 4244 }
  }
  enabled     = true
  description = "Allow ${each.key} from k8s controlplane to k8s workers"

  interface = {
    interface = [
      local.dhcp_subnets["k8s_cp"].interface,
    ]
  }

  categories = [
    opnsense_firewall_category.category["talos"].id
  ]

  filter = {
    quick     = true
    action    = "pass"
    direction = "in"
    protocol  = each.value.protocol

    source = {
      net = local.dhcp_subnets["k8s_cp"].interface
    }

    destination = {
      net  = local.dhcp_subnets["k8s_wk"].interface
      port = each.value.port
    }

    log = false
  }
}

resource "opnsense_firewall_filter" "worker_controlplane" {
  for_each = {
    "talos_trustd" = { protocol = "TCP", port = 50001 }
    "k8s_api"  = { protocol = "TCP", port = 6443 }
    "cilium_vxlan" = { protocol = "UDP", port = 8472 }
    "cilium_health" = { protocol = "TCP", port = 4240 }
  }
  enabled     = true
  description = "Allow ${each.key} from k8s workers to k8s controlplane"

  interface = {
    interface = [
      local.dhcp_subnets["k8s_wk"].interface,
    ]
  }

  categories = [
    opnsense_firewall_category.category["talos"].id
  ]

  filter = {
    quick     = true
    action    = "pass"
    direction = "in"
    protocol  = each.value.protocol

    source = {
      net = local.dhcp_subnets["k8s_wk"].interface
    }

    destination = {
      net  = local.dhcp_subnets["k8s_cp"].interface
      port = each.value.port
    }

    log = false
  }
}
