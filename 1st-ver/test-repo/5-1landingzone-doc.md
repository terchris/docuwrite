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
