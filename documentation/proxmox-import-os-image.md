# Download ISO Images on Proxmox

## OPNSense Appliance
Go over OPNSense official website: https://opnsense.org/download/

Copy the download link of the latest *dvd* image type, in my case the `26.1.2` version:
![opnsense-iso-download](/documentation/images/opnsense-iso-download.png)

On the same page, you'll see the the checksum verification as well as the key, you'll need these information on the following step:
![opnsense-iso-checksum](/documentation/images/opnsense-iso-checksum.png)

Go into the Proxmox management UI and select the right disk on the node used to deploy the VM:
![proxmox-node-storage](/documentation/images/proxmox-node-storage.png)

Select the disk > *ISO Images* > *Download from URL*

Then fill the parameters and hit download:
- **URL**: the copied download link
- **File name**: the file name to save to on the Proxmox host
- **Hash algorithm**: The hash algorithm, for in my case `SHA-256`
- **Checksum**: The key displayed on the OPNSense download page
- **Decompression algorithm**: `BZIP2`
![proxmox-iso-download](/documentation/images/proxmox-iso-download.png)

## Talos
Retrieve the latest `metal-amd64.iso` release available on the official talos repository: https://github.com/siderolabs/talos/releases

In my case, the latest available version I have is the `v1.13.0-alpha.2`, can be downloaded directly using iso link (https://github.com/siderolabs/talos/releases/download/v1.13.0-alpha.2/metal-amd64.iso)

Go into the Proxmox management UI and select the right disk on the node used to deploy the VM:
![proxmox-node-storage](/documentation/images/proxmox-node-storage.png)

Select the disk > *ISO Images* > *Download from URL*

Then fill the parameters and hit download:
- **URL**: the copied download link
- **File name**: the file name to save to on the Proxmox host
![proxmox-iso-download](/documentation/images/proxmox-iso-download.png)
