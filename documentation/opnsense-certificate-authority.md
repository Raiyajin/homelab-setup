# OPNsense Internal Certificate Authority

## Why Internal CA over Public CA ?

Since most usage would be private there is no real need for Public CA.

Using Internal CA comes with the advantage of being able to use private TLD (e.g., `.internal`)

And lastly, certificates generated with a public CA are logged and viewable by anyone (crt.sh), which basically provide information of services you might be running.

## Create and use OPNsense Internal Certificate Authority

Log in to your OPNsense administrator UI.

In the toggle menu at the right side, select "System" > "Trust" > "Authorities"

![opnsense-landing-page](./images/opnsense-landing-page-ca.png)

Then click on the "[+]" (add) button and fill out the fields, I recommend to not skip all "General" fields even though they're optional.

![opnsense-internal-ca-creation](./images/opnsense-internal-ca-creation.png)

Next we'll update the OPNsense administrator UI certificate.

Go to "System" > "Trust" > "Certificates".

Click on the "Pen" symbol next to the existing Web GUI certificate and update it to use our internal CA as issuer.

![opnsense-gui-certificate](./images/opnsense-gui-certificate.png)

To verify that its working, you must go back to the "Authorities" page and download the certificate.

[On Windows](https://learn.microsoft.com/en-us/skype-sdk/sdn/articles/installing-the-trusted-root-certificate), once downloaded update its extension to be ".crt" and double click on it.

Select "Install Certificate" > "Next" > "Local Computer" (need admin privileges) > "Next"

![windows-install-ca](./images/windows-install-ca.png)

Then click  "Place all certificates in the following store" and choose "Trusted Root Certification Authorities store" and hit "Next" and finish the process

![windows-place-ca](./images/windows-place-ca.png)

Open an incognito page using your opnsense domain and you'll see that the connection is secured !

![windows-secured-domain](./images/windows-secured-domain.png)