# Create an OPNsense Golden Image template

## Prepare the initial OPNsense config

Create and update the `config.xml` in the `iac/packer` folder.

See [iac/packer/config.xml](/iac/packer/config.xml) for an example that automate the assignment of interfaces

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