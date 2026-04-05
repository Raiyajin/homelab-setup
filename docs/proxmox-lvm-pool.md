# Add a LVM-thin in Proxmox

## Why LVM-thin
The biggest pro of LVM-Thin (Logical Volume Manager - Thin Provisioning) is that it allows for dynamic allocation of storage.
The tradeoff is a negligeable loss of performance and a small part of the storage that will be dedicated for metadata saving.

## Add a LVM-thin in Proxmox using the CLI

To add LVM-Thin, we need to create the Physical Volume (PV), a Volume Group (VG), and finally define the Thin Pool.

Let's take the example of a 26TB drive.

1. Initialize the Physical Volume (PV)

Retrieve the drive identifier:
```bash
lsblk -do NAME,SIZE,MODEL
```

First, initialize the volume by referencing the raw disk. Replace `/dev/sdX` with your actual drive identifier (e.g., `/dev/sda`).

```bash
pvcreate /dev/sda
```

2. Create the Volume Group (VG)

```bash
vgcreate hdd01 /dev/sda
```

3. Create the Thin Pool
This is the most important step. We create a "Thin Pool" inside the VG.

> [!NOTE]
> For large pool. We will explicitly set the metadata size to 1GB to start (it can grow later, but 1GB is a safe floor for large drives).

We create the pool with all the available space using `-l 100%FREE`:
```bash
lvcreate -l 100%FREE --thinpool hdd01 hdd01 --poolmetadatasize 1G
```