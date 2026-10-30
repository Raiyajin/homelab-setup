terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.119.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.12.0"
    }
    helm = {
      source  = "helm"
      version = "3.3.0"
    }
    kubernetes = {
      source  = "kubernetes"
      version = "~> 3.4.0"
    }
    vault = {
      source  = "vault"
      version = "~> 5.13.0"
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

provider "kubernetes" {
  host                   = "https://${local.bootstrapped_controlplane_ip}:6443"
  client_certificate     = base64decode(local.kubeconfig.client_certificate)
  client_key             = base64decode(local.kubeconfig.client_key)
  cluster_ca_certificate = base64decode(local.kubeconfig.ca_certificate)
}

provider "vault" {
  auth_login {
    path = var.approle_login_path

    parameters = {
      role_id   = var.approle_role_id
      secret_id = var.approle_secret_id
    }
  }
}