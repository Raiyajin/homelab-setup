terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.99.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.10.1"
    }
    helm = {
      source = "helm"
      version = "3.1.1"
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

provider "talos" {}
