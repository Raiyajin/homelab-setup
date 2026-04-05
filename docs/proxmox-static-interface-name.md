# Static name for network interfaces in proxmox

## Motivation
The main motivation of this documentation creation comes from an issue that happened to me.

Indeed, after rebooting one of my node, I lost ethernet connection and communication between devices within my network and the proxmox node.

As rebooting again and unpluggind cable didn't work, the only way to debug the issue was to connect physically to the node.

On my node, I first ruled out DNS issue by pinging a domain name and then an IP.
```bash
root@<node>:~# ping google.com
ping: google.com: Temporary failure in name resolution

root@<node>:~# ping 8.8.8.8
Pinging 8.8.8.8 with 32 bytes of data:
Request timed out.
```

Second thing I checked are my current interfaces, I was thinking of checking if the IP assigned by my ISP router was still there:
```bash
root@nas:~# ip a
...
2: enp5s0: <BROADCAST, MULTICAST, UP, LOWER UP> mtu 1500 qdisc mq master vmbr0 state UP group default qlen 1000
link/ether a8:b8:e0:06:94:31 brd ff:ff:ff:ff:ff:ff
3: enp6s0: <BROADCAST, MULTICAST, UP, LOWER UP> mtu 1500 qdisc mq master vmbr2 state UP group default qlen 1000
link/ether a8:b8:e0:06:94:32 brd ff: ff:ff:ff:ff:ff
4: enp7s0: <BROADCAST, MULTICAST, UP, LOWER UP> mtu 1500 qdisc mq master vmbr3 state UP group default qlen 1000
link/ether a8:b8:e0:06:94:33 brd ff: ff: ff:ff:ff:ff
5: enp8s0: <BROADCAST, MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
link/ether a8:b8:e0:06:94:34 brd ff: ff: ff:ff:ff:ff
6: vmbr0: <BROADCAST, MULTICAST, UP, LOWER UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
link/ether a8:b8:e0:06:94:31 brd ff: ff: ff:ff:ff:ff
inet <ASSIGNED-IP>/24 scope global vmbr0
valid lft forever preferred_lft forever
inet6 fe80: : aab8:e0ff:fe06:9431/64 scope link
valid lft forever preferred lft forever
...
```

It definitely was there but unreachable, so lastly I checked over the `/etc/network/interfaces`
```
root@nas:~# cat /etc/network/interfaces
iface enp4s0 inet manual

iface enp5s0 inet manual

iface enp6s0 inet manual

iface enp7s0 inet manual

auto vmbr0
iface vmbr0 inet static
address <ASSIGNED-IP>/24
gateway <GATEWAY-IP>
bridge-ports enp4s0
bridge-stp off
bridge-fd 0
...

That's where it occured to me that the current network interface associated to my bridge didn't exist anymore
```bash
root@nas :~ # ip a show enp4s0
Device "enp4s0" does not exist.
```

After browsing a little, I found over Proxmox Forum, a post named "The Joys of Spontaneous Network Interface Renaming", describing precisely my issue and permanent resolution steps.

## Assign a static name to an interface

Jebbam in the original post provided a script to automate it, here is the one I made based upon that script

> ![Note]
> The script render the current name as static for all future boot, so make sure you're fine with the current name of your interface

```bash
#!/bin/bash
/etc/systemd/network
for ETH in $(ls -1 /sys/class/net/ | sort -V | grep -v -e "^bond"  -e "^fwbr" -e "^fwln" -e "fwpr" -e "^lo$" -e "^tap" -e "^vmbr")
do cat > /etc/systemd/network/10-${ETH}.link <<EOF
[Match]
MACAddress=$(ip link show dev ${ETH} | grep "link/ether" | awk '{print $2}')
Type=ether

[Link]
Name=${ETH}
EOF
done

update-initramfs -u -k all
```

Once done, if you changed a name from what it was reboot and you'll see that all interfaces kept their name as defined in the /etc/systemd/network directory.