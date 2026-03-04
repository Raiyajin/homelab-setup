# Setting up the Packer plugin

This documentation explains how to set up the [hashicorp/proxmox](https://github.com/hashicorp/proxmox) plugin for Packer.

## Create an Packer user in Proxmox

Connect into the Proxmox host:
```bash
~# ssh root@<HOST-IP>

Password: <PASSWORD>
```

Create a user and assign the `PVEVMAdmin` role:
```bash
PASSWORD=<password>
pveum user add packer-user@pve --password $PASSWORD \
    && pveum aclmod / -user packer-user@pve -role PVEVMAdmin
```

Finally, generate a token to use it on the proxmox plugin:
```bash
pveum user token add packer-user@pve packer -expire 0 -privsep 0 -comment "Packer token"
```

### Add the plugin
Example for `opnsense.pkr.hcl`:
```
packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "opnsense_builder" {
  ...
}
```

We're using environment variables to initialize the plugin, here's an example of a `.env` file for that purpose:
```
# Packer environment variables
PROXMOX_URL = "https://<PROXMOX-IP>:8006/"
PROXMOX_USERNAME = "packer-user@pve!packer="
PROXMOX_TOKEN = <TOKEN>
```
