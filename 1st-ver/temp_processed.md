# External Context

The external facing part of the network is the part that is visible to the public.

:::mermaid
![Figure 1: External Context](diagram-01-external-context.png)
:::

## Subdomains and their routing

Our domain is redcross.no The new infrastructure will have 3 subdomains that are exposed to the outside. These are:

| Subdomain        | Description       | Dest landing zone        | Dest "host"       |
|------------------|-------------------| -------------------------| ------------------|
| api.redcross.no  | Production API    | Landing Zone Production  | APIM-prod         |
| test.redcross.no | Test API          | Landing Zone Test        | APIM-test         |
| dev.redcross.no  | Development API   | Landing Zone Development | APIM-dev          |

All of these subdomains are pointing to the same firewall.

The firewall routes traffic based on the subdomain to the correct landing zone.


## DNS

redcross.no is the domain. It is hosted on the DNS server in the "Betala per anvending" subscription.

When we set up the new subscription we point the DNS records defined in [External facing](2-0external-facing.md) to the new DNS server.


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


## Firewall documentation

We are using Azure Application Gateway as a firewall.
Documentation for the product is available at [Azure Application Gateway documentation](https://docs.microsoft.com/en-us/azure/application-gateway/).

Our special configuration is described below.

TODO: Describe the configuration of the firewall.



## Firewall Rules

Below are the firewall rules for integrations in Red Cross Norway.

hostname | Source | Destination | Port | Protocol | landing Zone  | Description
--- | --- | --- | --- | --- | --- | ---
api.redcross.no | * | APIM-prod | 443 | HTTPS | Production | API for the Red Cross |
api.redcross.no | * | APIM-prod | 80 | HTTP | Production | API for the Red Cross |
test.redcross.no | * | APIM-test | 443 | HTTPS | Test | test API for the Red Cross |
test.redcross.no | * | APIM-test | 80 | HTTP | Test | test API for the Red Cross |
dev.redcross.no | RC Intranet | APIM-dev | 443 | HTTPS | Development | dev API for the Red Cross |
dev.redcross.no | RC Intranet | APIM-dev | 80 | HTTP | Development | dev API for the Red Cross |

***NOTE:*** The `RC Intranet` is the internal network for the Red Cross Norway. It is not accessable from the internet.


## Firewall SSL termination

Our SSL certificate is a wildcard certificate for redcross.no. The certificate is installed on the Azure Application Gateway.

Currently the certificate is installed on the Firewall on the "Betala per anvending" subscription.
When we set up the new subscription we will install the certificate on the Azure Application Gateway. Then we will point the DNS records defined in [External facing](2-0external-facing.md) to the new Application Gateway.

TODO: Jah - is the certificate installed on the FW in the new subscription or the old?


## Firewall Logging

This document describes how to set up logging for the firewall.
We are collecting all logs in Sentinel.

TODO: Add information about logging and who is responsible for monitoring the logs.


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


## Landing Zone documentation overview

Landing zones are like subnets. They are isolated from each other.
As a general rule there are no comminication between landing zones.

There can be exceptions to this rule, but they should be well documented.

### Landing Zone Production

The production landing zone is where the production systems are located.
The landing zone is accessable from the internet.

### Landing Zone Test

This zone is accessable from the internet. It is used for testing systems before they are moved to production.
It has the same security rules as the production zone.

### Landing Zone Development

This zone is used for development. It is not accessable from the internet.

TODO: The dev landing zone can only be accessed from the internal network. How is this done?

### Landing Zone Build

This zone is used for the build server. It is not accessable from the internet.


## Landing Zone Production details

The production landing zone is where the production systems are located.
The landing zone is accessable from the internet.

Any details about the production landing zone should be documented here.


# Communication rules

All communication between systems must follow these rules.

## Internal communication (between systems internally)

Communication between internal systems must use Azure API Management (APIM). This is to ensure that we have a single point of entry for all communication. This makes it easier to monitor and secure the communication.

:::mermaid
![Figure 3: Internal communication (between systems internally)](diagram-03-internal-communication.png)
:::

In the example above, the `devfunction` is an Azure Function that is calling a `resource`. The resource is a web service that is accessing a database. The Azure Function is calling the resource through APIM.

***Functions can only call resources through APIM.***

## External communication (from internal systems to external systems)

Communication from internal systems to external systems must use Azure API Management (APIM). We are doing  this so that we can respond to changes on external APIs. If an external API changes, we can update the APIM to reflect the changes. This way, we don't have to update all the internal systems that are calling the external API.

:::mermaid
![Figure 4: External communication (from internal systems to external systems)](diagram-04-external-communication.png)
:::

## Requests from external systems to internal systems

Requests from external systems to internal systems will first go trugh the firewall and then to APIm in the landing zone. See [External facing](2-0external-facing.md) for more information.

APIM will route the request to the correct internal system.

:::mermaid
![Figure 5: Requests from external systems to internal systems](diagram-05-requests-from-external-systems-to-internal-systems.png)
:::

## Definition of external systems

***All systems on the old Azure "Betala per andvending" are external systems.***

External systems are systems that are not part of the new Azure environment. These systems are accessed through the internet.

TODO: we need to make everyone aware of the consequences of this.


# Communication rules exceptions

This document describes what is needed to make an exception to the communication rules defined in [6-0communication-rules.md](6-0communication-rules.md).

TODO: If there should ever be exceptions to the comminication rules. We ned to document how we make exceptions to the rules.


# Development

This document describes the development setup for Red Cross Norway. It is intended for developers who create and maintan integrations.

- [Build server](8-1build-server.md)
- [DevOps](8-2devops.md)
- [Azure Functions](8-3functions.md)
- [Naming conventions](7-0naming-caf.md)
- [Infrastructure as code](8-4infrastructure-as-code.md)
- [Development Security](8-5development-security.md)


## Build server

Deploy from DevOps does not work because DevOps has no access into the Landing zones. There is therefore a build server.

:::mermaid
![Figure 6: Build server](diagram-06-build-server.png)
:::

The build server is a virtual machine that has access to the landing zones. The build server is monitoring the source code repository for changes. When a change is detected, the build server pulls the source code and builds the application. The build server then deploys the application to the correct landing zone.


### How to set up the build server for a repository

TODO: Describe how to set up the build server for a repository.



# DevOps

Azure DevOps services are used during development and deployment of integrations.

## Development Process
1. Get IntegrationID according to [Naming conventions](7-0naming-caf.md) from the central register of integrations.
2. Identify the repo to be use. It might be an existing repo according to the central register of integrations. If a new repo is needed create the repo and follow naming conventions. <i>TODO: Naming?</i>
3. Secret information e.g. usernames, passwords, subscription keys, certificates should never be commited into a repo. Use [Azure Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/general/basic-concepts) for storing secrets.
4. Use [Managed Identity](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview) when possible for securing communication between Azure services. Use role-based access control (RBAC) to grant permissions.
5. Always use feature branches and merge to master after a pull request.
6. Always build and deploy integrations with Pipelines. A Pipeline should deploy to all target environments with approvals and checks setup.

TODO: Decide how pipelibe should be setup?

TODO: decide naming conventions for repos.

## Repo 
All source code should be commited and pushed into a repo.
A repo group one or more integrations related to a domain or process. In addition, integrations related to a business applications relation can be grouped e.g. all integrations between system A and system B.

The main folder structure is described in the next section [Delivery Pipeline](#delivery-pipeline).

## Delivery Pipeline
All deliveries of integration artifacts should be orchestrated with Azure Pipelines.

The Delivery pipeline is divided into three parts. The main part which is triggered when new code is pushed to the repository. The stages of the delivery pipeline are implemented here. It is defined in a file called <i>azure-pipelines.yaml</i>.
The commit pipeline implements all jobs that should be run to prepare the artifacts for deployment, like compile, validate and test. It is defined in a file called <i>commit.yaml</i>
The release pipeline implements all jobs that deploy artifacts to a specified environment. It is defined in a file called <i>release.yaml</i>.

:::text
.
+-- .pipeline
|   +-- commit.yaml
|   +-- release.yaml
+-- apis
+-- azure-pipelines.yaml
+-- components
+-- resources
:::

Integrio has gathered their best practices into reusable pipeline templates. This standardization minimizes variations and potential errors that can arise from manual configurations or individual interpretations of documentation.

The library and how to use it can be found here: [Pipeline Templates](https://dev.azure.com/RedCrossNorway/Integrations/_wiki/wikis/Integrio%20Pipeline%20Templates/524/index)


## Bicep Modules
Integrio har gathered their best practices into reusable Bicep modules that ensure that every piece of infrastructure is built to the same standards. This standardization minimizes variations and potential errors that can arise from manual configurations or individual interpretations of documentation.

The library and how to use it can be found here: [Bicep Modules](https://dev.azure.com/RedCrossNorway/Integrations/_wiki/wikis/Integrio%20Bicep%20Modules/536/index)

## Service Connections
The Azure Pipelines that deploys integrations need Service Connections to be able to create and/or updates Azure resources.
The existing Service Connections that should be used are listed in the table below.

| Name                                  | Target Environment                        |Description                                                                    |
|---------------------------------------|-------------------------------------------|-------------------------------------------------------------------------------|
| nrx-integrations-dev-sp               | Landing Zone Development                  | Used to deploy integrations in the DEV environment.                           |
| nrx-integrations-test-sp              | Landing Zone Test                         | Used to deploy integrations in the TEST environment.                          |
| nrx-integrations-prod-sp              | Landing Zone Production                   | Used to deploy integrations in the PROD environment.                          |
| nrx-integrations-payg-sp              | Betala per användning                     | Used to deploy integrations in the old Azure environment (Dev, Staging, Prod).|
| igr-integration-acr-sp                | Integrio Infra                            | Used to reference Bicep modules published in Integrio ACR.                    |
| igr-integration-devops-sp             | Integrio DevOps                           | Used to reference Pipeline templates in Integrio DevOps.                      |


<br>

### Service Connections Overview
<br>


:::mermaid
![Figure 7: Service Connections Overview](diagram-07-service-connections-overview.png)
:::


## Azure Functions

Azure Functions is a serverless compute service that enables you to run event-triggered code without having to explicitly provision or manage infrastructure. Using Azure Functions, you can run a script or piece of code in response to a variety of events. Azure Functions can be used to process data, integrate systems, trigger alerts, and more.

### CAF naming conventions

Azure Functions should follow the [CAF naming conventions](7-0naming-caf.md).

### Programming languages

TODO: we need to decide on which programming languages to support in Azure Functions.

### Storage for Azure Functions

TODO: if we decide that each function needs its own storage account, we need to follow CAF naming conventions for storage accounts. We also need to figure out pricing related to storage accounts.


## Infrastructure as Code

IaC, Infrastructure as Code, gives the ability to always be able to deploy the same code that has been committed in the repository. Two languages that enables this (together with other tooling) are Bicep and YAML.

---

### Bicep
A recommended way to deploy Azure resources and infrastructure is to use Azure Bicep as IaC (Infrastructure as Code). Bicep gives the advantage of modularity and reusability, and will be compiled and translated into ARM templates (Azure Resource Manager) when deployed. ARM code is relatively verbose and difficult to write, Bicep has a much simpler syntax.

There is a lot of documentation on how to use Bicep, for example:
- Microsoft Bicep documentation: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/
- Microsoft Fundamentals of Bicep: https://learn.microsoft.com/en-us/training/paths/fundamentals-bicep/

In order to develop Bicep code on a developer machine, it is recommended to install and use VS Code and the VS Code Bicep extension.

As mentioned, Bicep has the advantage of being able to organize into modules. Bicep is also idempotent, and the same bicep file can be deployed multiple times if needed, and you will get the same resources and in the same state every time. 
It is perfectly possible to write Bicep code all from scratch, and even create your own modules. However, to alleviate some of this work (and at the same time get tried-and-tested bicep code), there is also the possibility to use existing modules. These modules exist in a separate repository and can be referenced from your Bicep code. For more information, see [Integrio Bicep Modules](https://dev.azure.com/RedCrossNorway/Integrations/_wiki/wikis/Integrio%20Bicep%20Modules/534/README)

### YAML
YAML is used when writing the pipeline that constructs the Devops CI/CD chain. There are also pre-created YAML-templates that exists in another separate repository, which can be referenced from your YAML files. For more information, see [Integrio Pipeline Templates](https://dev.azure.com/RedCrossNorway/Integrations/_wiki/wikis/Integrio%20Pipeline%20Templates/524/index)

<br>

---

### Terraform
TBD.


# Development security

TODO: describe how we handle security in development (service principals, keyvault, etc.)

This document describes:

- service principals

- keywault

## Service principals

## Keyvault


# CAF Naming conventions

We are using CAF naming conventions.
The purpose of having defined naming standards is to make it possible to identify what a resource does and where it belongs just by looking at the name.

## CAF naming convention for the Azure Functions

We have a central register of all integrations. The IntegrationID is a unique identifier for each integration. The IntegrationID is used in the name of the function app.

The format of the integration ID is "int" followed by a three-digit number. The number is unique for each integration.

TODO: we must make final decition on naming. Can the integration number can be added as a tag?

Functions need to be named in a CAF compliant way:

Name: func-api-testfunction-int0001-euw

| Keyword | Example       | Chars | Description                                                                                               |
|---------|---------------|-------|-----------------------------------------------------------------------------------------------------------|
|         | `func`        | 3    | Indicates the resource is a Function App.                                                                 |
|         | `api`         | 3    | Denotes the integration landing zone.                                                                     |
|         | `testfunction`| 12    | Specifies the name of the function app.                                                                   |
|         | `int001`      | 6    | The unique IntegrationID from our tracking system.                                                        |
|         | `eus`         | 3    | The region abbreviation for East US.                                                                      |
|         | `01`          | 2    | A two-character hexadecimal to make the name unique. An instance or sequence number for versioning or multiple instances. |

## CAF naming convention for Azure Storage accounts

Azure Storage account names must be between 3 and 24 characters in length and can contain only lowercase letters and numbers. And it ***must be unique across all of Azure***.

TODO: Storage accounts are hard to name as they must be unique across all of Azure. What is the best practice for naming?

Because of the lenght of maximum 24 characters we have limited the length of the integration ID to 6 characters.

Name: stapitestfnint001eus01

| Keyword | Example | Chars | Description                                                                                      |
|---------|---------|-------|--------------------------------------------------------------------------------------------------|
|     | `st`    | 46    | 2 char that denotes it's a storage account.                                                      |
|    | `api`   | 64    | Max 4 char that indicate landing zone. Indicates it's part of the API landing zone.              |
|  | `testfn`| 22    | 6 char for the name                                                                              |
|  | `int001`| 24    | 6 char Integration ID                                                                            |
|     | `eus`   | 61    | 3 char that Specifies the Azure region (East US) for the storage account.                        |
|     | `01`    | 60    | A two char hex to make the name unique.                                                          |

The above rule will use the maximum length of 24 characters.

Functions have separate storage accounts so that different teams do not interfere with each other. This is a best practice for isolation and security.

TODO: What is the costs associated with storage accounts? Should we have separate storage accounts for each function app?


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



# Infrastructure / integrations documentation for Red Cross Norway

This document describes the infrastructure and how to develop integrations for Red Cross Norway. It is intended for developers and administrators who work with integrations.

All documentation here is automatically compiled into one [PDF that can be found here](documentation.pdf). In the PDF file you will find a list of TODO:s that are not yet implemented in the documentation.

- [Readme first](1-0readme-first.md)
- [Generated TODO list](todo-list.md)
- [Costs](1-1costs.md)
- [External facing](2-0external-facing.md)
- [DNS](3-0dns.md)
- [Firewall](4-0firewall.md)
  - [Firewall documentation](4-3firewall-doc.md)
  - [Firewall Rules](4-2firewall-rules.md)
  - [Firewall SSL termination](4-1firewall-ssl.md)
  - [Firewall logging](4-4firewall-logging.md)
- [Landing Zones for integrations](5-0landingzones.md)
  - [Landing Zone documentation](5-1landingzone-doc.md)
- [Rules for communication (in and out of our systems and between internal systems)](6-0communication-rules.md)
- [Communication rules exceptions](6-1communication-rules-exceptions.md)
- [Development setup](8-0development.md)
  - [Build server](8-1build-server.md)
  - [DevOps](8-2devops.md)
  - [Azure Functions](8-3functions.md)
  - [Infrastructure as code](8-4infrastructure-as-code.md)

- [CAF naming conventions](7-0naming-caf.md)
- [how we write the documentation](x-0howto-doc.md)




# TODO List

TODO List

| Section | TODO Item |
|---------|----------|
| Firewall documentation | Describe the configuration of the firewall. |
| Firewall SSL termination | Jah - is the certificate installed on the FW in the new subscription or the old? |
| Firewall Logging | Add information about logging and who is responsible for monitoring the logs. |
| Landing Zone Development | The dev landing zone can only be accessed from the internal network. How is this done? |
| Definition of external systems | we need to make everyone aware of the consequences of this. |
| Communication rules exceptions | If there should ever be exceptions to the comminication rules. We ned to document how we make exceptions to the rules. |
| How to set up the build server for a repository | Describe how to set up the build server for a repository. |
| Development Process | Decide how pipelibe should be setup? |
| Development Process | decide naming conventions for repos. |
| Programming languages | we need to decide on which programming languages to support in Azure Functions. |
| Storage for Azure Functions | if we decide that each function needs its own storage account, we need to follow CAF naming conventions for storage accounts. We also need to figure out pricing related to storage accounts. |
| Development security | describe how we handle security in development (service principals, keyvault, etc.) |
| CAF naming convention for the Azure Functions | we must make final decition on naming. Can the integration number can be added as a tag? |
| CAF naming convention for Azure Storage accounts | Storage accounts are hard to name as they must be unique across all of Azure. What is the best practice for naming? |
| CAF naming convention for Azure Storage accounts | What is the costs associated with storage accounts? Should we have separate storage accounts for each function app? |
