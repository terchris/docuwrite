# Costs

This is an overview of the costs for the infrastructure for Red Cross Norway.

| Product                              | Description                               | Version                      | Monthly Cost |
|--------------------------------------|-------------------------------------------|------------------------------|--------------|
| Azure Application Gateway            | Firewall                                  |                              |     *?1      |
| Azure Web Application Firewall (WAF) | Firewall - exploits protection            |        included              |              |
| Azure DDoS Protection                | Firewall - DDoS protection                |  Basic is included           |              |
| Azure API Management                 | APIM prod                                 | API Management, Standard v2  | kr7,523      |
| Azure API Management                 | APIM test                                 | API Management, Standard v2  | kr7,523      |
| Azure API Management                 | APIM dev                                  | API Management, Standard v2  | kr7,523  *?2 |
| Landing Zone Prod                    | Landing zone for production               |                              |              |
| Landing Zone Test                    | Landing zone for testing                  |                              |              |
| Landing Zone Dev                     | Landing zone for development              |                              |              |
| Landing Zone Build                   | Landing zone for build server             |                              |              |
| Build server                         | Linux VM that builds and deploys          |                              |              |

Questions:

1) "Azure Application Gateway: Overview: Azure Application Gateway is a platform-managed, scalable, and highly available application delivery controller (ADC) as a service. It provides layer 7 load balancing, centralized SSL offload, and integrated web application firewall (WAF) capabilities."
Azure DDoS Protection Basic is included, Standard is an extra service.
It seems that all the stuff we need is in the same product.
We already have a firewall in the new CleanAzure subscription. It is named afw-prod-hub-network-euw so we do not need another one!

2) Can we use the API Management "Basic" or developer tier instead of "Standard v2" for the dev landing zone?
 See costs for API Management [here](https://azure.microsoft.com/en-us/pricing/details/api-management/)

