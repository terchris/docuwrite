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
