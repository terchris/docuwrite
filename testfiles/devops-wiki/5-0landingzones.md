# Landing Zones

Integrations are using three landing zones. The landing zones are separate environments for production, test, and development. The landing zones are isolated from each other. Each landing zone has its own set of resources.

## Integration Landing Zones

The landing zones are:

| Landing Zone | Long name | Description |
|--------------|------------|-------------|
| landing-prod          | prod - azure integrations -az - red cross        | production landing zone |
| landing-test     | test - azure integrations -az - red cross        | test landing zone |
| landing-dev     | dev - azure integrations -az - red cross        | development landing zone |

***IMPORTANT: Isolation*** The landing zones are isolated from each other. It means that an application running in one landing zone cannot access a resource in another landing zone. The landing zones are isolated to prevent unauthorized access to resources.

***IMPORTANT: No inbound access*** There is no way to access any resources in the landing zones from the internet or the redcross internal network. All access to the landing zones is through the firewall.

Because of the isolation, the build server is the only way to deploy applications to the landing zones. The build server has access to all landing zones and can deploy applications to any of them. See more about the build server in the [build server](8-1build-server.md) documentation.

## Landing Zones diagram

The diagram below shows the landing zones and the resources in each landing zone.

:::mermaid
graph LR
   subgraph "landing-prod"
       apim1(APIM)
       prodfunction(prodfunction)
   end
   
   subgraph "landing-test"
       apim2(APIM)
       testfunction(testfunction)
   end

   subgraph "landing-dev"
       apim3(APIM)
       devfunction(devfunction)
   end

   subgraph "landing-build"
       vm01(buildserver)
   end

   Firewall(Firewall)
   internet(Internet) --> Firewall

   classDef plain fill:#ddd,stroke:#fff,stroke-width:4px,color:#000;
   classDef activeVM fill:#326ce5,stroke:#fff,stroke-width:4px,color:#fff;
   classDef controller fill:#326ce5,stroke:#fff,stroke-width:4px,color:#fff;
   classDef zone fill:#fff,stroke:#bbb,stroke-width:2px,color:#326ce5;
   classDef groupCluster fill:#e8f0fe,stroke:#bbb,stroke-width:2px,color:#000; 
   classDef groupFunction fill:#e8f0fe,stroke:#bbb,stroke-width:2px,color:#000; 

   class vm01 activeVM;
   class apim1,apim2,apim3 controller;
   class landing-prod,landing-test,landing-dev,landing-build zone;

   Firewall --> apim1
   Firewall --> apim2
   Firewall --> apim3
   vm01 -. push .-> landing-prod
   vm01 -. push .-> landing-test
   vm01 -. push .-> landing-dev
   vm01 -. pull .-> DevOps
:::
