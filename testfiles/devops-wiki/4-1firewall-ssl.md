## Firewall SSL termination

Our SSL certificate is a wildcard certificate for redcross.no. The certificate is installed on the Azure Application Gateway.

Currently the certificate is installed on the Firewall on the "Betala per anvending" subscription.
When we set up the new subscription we will install the certificate on the Azure Application Gateway. Then we will point the DNS records defined in [External facing](2-0external-facing.md) to the new Application Gateway.

TODO: Jah - is the certificate installed on the FW in the new subscription or the old?
