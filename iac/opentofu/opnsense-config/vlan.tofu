resource "opnsense_interfaces_vlan" "vlan" {
  for_each = {
    K8S_CP      = { tag = 10, parent = "vtnet1" }
    K8S_WK      = { tag = 20, parent = "vtnet1" }
    WIFI_SECURE = { tag = 30, parent = "vtnet2" }
    WIFI_GUEST  = { tag = 40, parent = "vtnet2" }
  }

  description = each.key
  tag         = each.value.tag
  parent      = each.value.parent
}

# Assignment of the VLAN and subnet is done manually for now (https://github.com/opnsense/core/issues/9345)