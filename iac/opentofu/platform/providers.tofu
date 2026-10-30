terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.119.0"
    }
    opnsense = {
      version = "~> 0.26.0"
      source  = "browningluke/opnsense"
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

/* To use need to have the following environment variables set:
OPNSENSE_URI
OPNSENSE_API_KEY
OPNSENSE_API_SECRET
*/
provider "opnsense" {
  allow_insecure = true
}
