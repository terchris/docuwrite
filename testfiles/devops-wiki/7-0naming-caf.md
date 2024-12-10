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
