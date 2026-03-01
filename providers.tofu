terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.97.1"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_host
  api_token = var.proxmox_api_token
  insecure = true
  ssh {
    agent    = true
    username = "root"
  }
}