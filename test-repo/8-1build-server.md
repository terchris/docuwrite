## Build server

Deploy from DevOps does not work because DevOps has no access into the Landing zones. There is therefore a build server.

:::mermaid
flowchart LR

    subgraph "landing-build"
     build(buildserver)
    end

    build -- push --> landing-prod[Landing zone prod]
    build -- push --> landing-test[Landing zone test]
    build -- push --> landing-dev[landing zone dev]
    build -- pull --> DevOps
:::

The build server is a virtual machine that has access to the landing zones. The build server is monitoring the source code repository for changes. When a change is detected, the build server pulls the source code and builds the application. The build server then deploys the application to the correct landing zone.


### How to set up the build server for a repository

TODO: Describe how to set up the build server for a repository.

