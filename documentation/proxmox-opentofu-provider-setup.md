# Setting up the OpenTofu provider

This documentation explains how to set up the [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest/docs#when-is-ssh-required) provider for OpenTofu.

## Create an OpenTofu user in Proxmox

Connect into the Proxmox host:
```bash
~# ssh root@<HOST-IP>

Password: <PASSWORD>
```

Create a Proxmox role:
```bash
pveum role add opentofu-role -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Console VM.Migrate VM.Monitor VM.PowerMgmt SDN.Use"
```

Create a user and assign the role:
```bash
PASSWORD=<password>
pveum user add opentofu-user@pve --password $PASSWORD \
    && pveum aclmod / -user opentofu-user@pve -role opentofu-role
```

Finally, generate a token to use it on the proxmox provider:
```bash
pveum user token add opentofu-user@pve opentofu -expire 0 -privsep 0 -comment "OpenTofu token"
```

## (Optional) Add an ssh key to the Proxmox host for specific resources:
The following resources from the bpg/proxmox provider requires ssh agent
- `proxmox_virtual_environment_file`
- `proxmox_virtual_environment_file`
- `proxmox_virtual_environment_vm`
- `proxmox_virtual_environment_container`

Use an existing key or generate one on the local machine:
```bash
ssh-keygen -t ed25519
```

Copy the public key:
```
cat ~/.ssh/id_ed25519.pub
```

Paste it on the Proxmox host:
```
cat <<EOF >> ~/.ssh/authorized_keys
<PASTE-HERE>
EOF
```

### Add the provider with the generated credentials
Example of `providers.tf`:
```
terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.97.1"
    }
  }
}

provider "proxmox" {
  endpoint = "https://<PROXMOX-IP>:8006/"
  api_token = <TOKEN>
  insecure = false
  ssh {
    agent    = true
    username = "root"
  }
}
```