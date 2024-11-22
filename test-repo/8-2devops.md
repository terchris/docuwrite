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

graph LR

    subgraph "nrx-devops"
       pipeline(Pipeline)
   end

   subgraph "nrx-azure"
        landing-build(landing-build)
        landing-dev(landing-dev)
        landing-test(landing-test)
        landing-prod(landing-prod)
        pay-as-you-go(pay-as-you-go)    
   end

   subgraph "integrio-devops"
       pipeline-templates(pipeline-templates)
   end

   subgraph "integrio-acr"
       bicep-modules(bicep-modules)
   end

    pipeline-templates --> pipeline
    bicep-modules --> pipeline
    pipeline -- pull --> landing-build
    pipeline -- push --> pay-as-you-go
    landing-build -. monitoring .-> pipeline
    landing-build --> landing-dev
    landing-build --> landing-test
    landing-build --> landing-prod


   
   classDef plain fill:#ddd,stroke:#fff,stroke-width:4px,color:#000;
   classDef controller fill:#326ce5,stroke:#fff,stroke-width:4px,color:#fff;
   classDef zone fill:#fff,stroke:#bbb,stroke-width:2px,color:#326ce5;
   classDef groupCluster fill:#e8f0fe,stroke:#bbb,stroke-width:2px,color:#000;
:::
