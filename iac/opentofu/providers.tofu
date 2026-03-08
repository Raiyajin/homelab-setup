terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.97.1"
    }
  }
}

provider "proxmox" {
  insecure = true
  ssh {
    agent    = true
    username = "root"
  }
}