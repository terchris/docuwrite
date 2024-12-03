# Communication rules

All communication between systems must follow these rules.

## Internal communication (between systems internally)

Communication between internal systems must use Azure API Management (APIM). This is to ensure that we have a single point of entry for all communication. This makes it easier to monitor and secure the communication.

:::mermaid
graph LR
 apim(APIM)
 db[("`db`")] 
 devfunction1(devfunction1)
 devfunction2(devfunction2)
 devfunction3(devfunction3)
 resource(Resource)

 classDef controller fill:#326ce5,stroke:#fff,stroke-width:4px,color:#fff;
 class apim controller;
 
devfunction1 <--> apim
apim --> resource 
resource <-..-> db
devfunction2 <--> apim <--> devfunction3
:::

In the example above, the `devfunction` is an Azure Function that is calling a `resource`. The resource is a web service that is accessing a database. The Azure Function is calling the resource through APIM.

***Functions can only call resources through APIM.***

## External communication (from internal systems to external systems)

Communication from internal systems to external systems must use Azure API Management (APIM). We are doing  this so that we can respond to changes on external APIs. If an external API changes, we can update the APIM to reflect the changes. This way, we don't have to update all the internal systems that are calling the external API.

:::mermaid
graph LR
    subgraph "security-zone"
       firewall(Firewall)
       internetgw(InternetGW)
   end

   subgraph "landing-zone"
       apim1(APIM)
       prodfunction1(prodfunction1)
       prodfunction2(prodfunction2)
   end

   apim1 --> firewall  
   firewall --> internetgw
   internetgw --> internet(Internet)
   internet --> internetresource1(brreg.no)
   internet --> internetresource2(external api)
   prodfunction1 --> apim1
   prodfunction2 --> apim1

   class apim1 controller;
   class landing-zone zone;
   classDef plain fill:#ddd,stroke:#fff,stroke-width:4px,color:#000;
   classDef controller fill:#326ce5,stroke:#fff,stroke-width:4px,color:#fff;
   classDef zone fill:#fff,stroke:#bbb,stroke-width:2px,color:#326ce5;
   classDef groupCluster fill:#e8f0fe,stroke:#bbb,stroke-width:2px,color:#000;
:::

## Requests from external systems to internal systems

Requests from external systems to internal systems will first go trugh the firewall and then to APIm in the landing zone. See [External facing](2-0external-facing.md) for more information.

APIM will route the request to the correct internal system.

:::mermaid
graph LR
    subgraph "security-zone"
       firewall(Firewall)
   end

   subgraph "landing-zone"
       apim1(APIM)
       prodfunction1(prodfunction1)
       prodfunction2(prodfunction2)
   end

   firewall --> apim1
   internet(Internet) --> firewall
   internetresource1(external api1) --> internet
   internetresource2(external api2) --> internet

   apim1 --> prodfunction1
   apim1 --> prodfunction2

   class apim1 controller;
   class landing-zone zone;
   classDef plain fill:#ddd,stroke:#fff,stroke-width:4px,color:#000;
   classDef controller fill:#326ce5,stroke:#fff,stroke-width:4px,color:#fff;
   classDef zone fill:#fff,stroke:#bbb,stroke-width:2px,color:#326ce5;
   classDef groupCluster fill:#e8f0fe,stroke:#bbb,stroke-width:2px,color:#000;
:::

## Definition of external systems

***All systems on the old Azure "Betala per andvending" are external systems.***

External systems are systems that are not part of the new Azure environment. These systems are accessed through the internet.

TODO: we need to make everyone aware of the consequences of this.
