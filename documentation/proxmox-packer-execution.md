# Create an OPNsense Golden Image template

## Prepare the initial OPNsense config

Create and update the `config.xml` in the `iac/packer` folder.

Here's mine that is used exclusively to assign interfaces automatically:
```
<opnsense>
  <interfaces>
    <wan>
      <if>vtnet0</if>
      <descr>WAN_FROM_ROUTER</descr>
      <enable>1</enable>
      <ipaddr>dhcp</ipaddr>
      <blockpriv>0</blockpriv> 
      <blockbogons>0</blockbogons>
    </wan>
    <lan>
      <if>vtnet1</if>
      <descr>MANAGEMENT_LAN</descr>
      <enable>1</enable>
      <ipaddr>10.0.0.1</ipaddr>
      <subnet>24</subnet>
    </lan>
    <opt1>
      <if>vtnet2</if>
      <descr>DMZ_SERVERS</descr>
      <enable>1</enable>
      <ipaddr>10.0.1.1</ipaddr>
      <subnet>24</subnet>
    </opt1>
    <opt2>
      <if>vtnet3</if>
      <descr>PC_ISOLATED</descr>
      <enable>1</enable>
      <ipaddr>10.0.2.1</ipaddr>
      <subnet>24</subnet>
    </opt2>
  </interfaces>
  <dhcpd>
    <lan>
      <enable>1</enable>
      <range><from>10.0.0.100</from><to>10.0.0.200</to></range>
    </lan>
    <opt1>
      <enable>1</enable>
      <range><from>10.0.1.100</from><to>10.0.1.200</to></range>
    </opt1>
    <opt2>
      <enable>1</enable>
      <range><from>10.0.2.100</from><to>10.0.2.200</to></range>
    </opt2>
  </dhcpd>
</opnsense>
```

Update the `opnsense.auto.pkvars.hcl` with your values
```
proxmox_node     = "<NODE-NAME>"
opnsense_version = "<VERSION>"
```

Finally build the template:
```
packer build .
```

It took me around ~8min to build my template. Your mileage may vary.

> [!TIP]
> If the script blocks, it may mean that the wait values used aren't adapted to your setup so you may increase wait times for involuntarily skipped steps.
>
> To debug issues, run the template with the `-on-error=ask` flag:
> ```
> packer build -on-error=ask .
> ```