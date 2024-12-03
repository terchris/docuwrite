# External Context

The external facing part of the network is the part that is visible to the public.

:::mermaid
graph TD;
    Internet{Internet}
    DNS[DNS for redcross.no]
    FW[Firewall]

    APIM_Prod[APIM-prod]
    APIM_Test[APIM-test]
    APIM_Dev[APIM-dev]

    API[api.redcross.no]
    TestAPI[test.redcross.no]
    DevAPI[dev.redcross.no]

    Internet --> DNS
    DNS --> API
    DNS --> TestAPI
    DNS --> DevAPI

    API --> FW
    TestAPI --> FW
    DevAPI --> FW

    FW --> APIM_Prod
    FW --> APIM_Test
    FW --> APIM_Dev

    classDef ext fill:#f96;
    class Internet,DNS ext;

    classDef api fill:#bbf,stroke:#f66,stroke-width:2px;
    class API,TestAPI,DevAPI api;

    classDef internal fill:#ff9;
    class FW internal;

    classDef apim fill:#00f,stroke:#fff,stroke-width:2px, color:#fff;
    class APIM_Prod,APIM_Test,APIM_Dev apim;

    subgraph LZ_Prod_Box["Landing Zone Production"]
        APIM_Prod
    end

    subgraph LZ_Test_Box["Landing Zone Test"]
        APIM_Test
    end

    subgraph LZ_Dev_Box["Landing Zone Development"]
        APIM_Dev
    end

    style LZ_Prod_Box fill:#ff0,stroke:#333,stroke-width:2px
    style LZ_Test_Box fill:#ff0,stroke:#333,stroke-width:2px
    style LZ_Dev_Box fill:#ff0,stroke:#333,stroke-width:2px
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
