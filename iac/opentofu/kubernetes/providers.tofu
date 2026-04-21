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
      source  = "helm"
      version = "3.1.1"
    }
    vault = {
      source = "vault"
      version = "~> 5.8.0"
    }
  }
}

provider "proxmox" {
  insecure = false
  ssh {
    agent    = true
    username = "root"
  }
}

provider "talos" {}

provider "vault" {
  auth_login {
    path = var.approle_login_path

    parameters = {
      role_id   = var.approle_role_id
      secret_id = var.approle_secret_id
    }
  }
}