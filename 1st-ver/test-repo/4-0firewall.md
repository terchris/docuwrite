## Firewall

The firewall is the first line of defense for the network. It is the only part of the network that is exposed to the internet. The firewall routes traffic based on the subdomain to the correct landing zone.

### Firewall functionality

We are using Azure Application Gateway as a firewall. The Application Gateway is the only resource with a public IP address. The Application Gateway terminates SSL and routes traffic based on subdomain.

:::mermaid
graph LR;
 client([client])-. web or API <br> request .->firewall[Azure Application Gateway];
 firewall-->|routing rule|service[dispatcher?];
 subgraph Firewall functionality
 firewall;
 service-->pod1[Landing zone Prod];
 service-->pod2[landing zone Test];
 service-->pod3[Landing zone Dev];
 end
 classDef plain fill:#ddd,stroke:#fff,stroke-width:4px,color:#000;
 classDef k8s fill:#326ce5,stroke:#fff,stroke-width:4px,color:#fff;
 classDef cluster fill:#fff,stroke:#bbb,stroke-width:2px,color:#326ce5;
 class firewall,service,pod1,pod2,pod3 k8s;
 class client plain;
 class cluster cluster;
 :::

For mre details see:

| What         | Description       |
|------------------|-------------------|
| [Firewall Rules](4-2firewall-rules.md)  | describes the firewall rules    |
| [Firewall SSL termination](4-1firewall-ssl.md) | describes the SSL termination on the firewall          |
| [Firewall doc](4-3firewall-doc.md) | describes firewall doc          |
| [Firewall logging](4-4firewall-logging.md) | describes how to set up logging for the firewall          |
