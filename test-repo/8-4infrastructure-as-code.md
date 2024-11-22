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
