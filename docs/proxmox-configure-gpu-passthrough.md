# Configure GPU Passthrough on Proxmox

Make sure your bios have IOMMU support and have virtualization enable.

In proxmox, check your cpu supports it
```
if $(cat /proc/cpuinfo | grep -E "vmx|svm" &>/dev/null); then echo "supported"; else echo "unsupported"; fi
```

Change GRUB_CMDLINE_LINUX_DEFAULT="quiet"

* for Intel CPU:
```bash
sed -i S/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"/ /etc/default/grub
```

* for AMD CPU:
```bash
sed -i S/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"/ /etc/default/grub
```

Update grub and reboot
```bash
update-grub
reboot
```

Check IOMMU is enabled
```bash
dmesg | grep -i "IOMMU"
```

Add VFIO modules to allow attaching directly to VM:
```bash
cat >> /etc/modules <<EOF
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF

# Help to improve virtualization compatibility 
echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/iommu_unsafe_interrupts.conf
echo "options kvm ignore_msrs=1" > /etc/modprobe.d/kvm.conf

# Disable GPU usage from Proxmox host
cat >> /etc/modprobe.d/blacklist.conf <<EOF
blacklist radeon
blacklist nouveau
blacklist nvidia
EOF
```

Lookup the GPU and audio devices and add them to the VFIO configuration file:
```bash
echo "options vfio-pci ids=$(lspci -nn | grep -i -e 'vga' -e 'audio' | awk -F'[][]' '{print $(NF-1)}' | paste -sd, - | sed 's/,/, /g') disable_vga=1" > /etc/modprobe.d/vfio.conf
```

Update and final reboot
```bash
update-initramfs -u
reboot
```