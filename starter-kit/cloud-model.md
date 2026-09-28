# Cloud Service Model

## Recommended Model: PaaS

KijaniKiosk should use a Platform as a Service (PaaS) model for its application.

PaaS provides a managed environment where developers can deploy and run the application without managing the underlying servers, operating systems, and much of the infrastructure.

## Why PaaS?

PaaS is suitable because:

- It reduces the amount of infrastructure that the development team needs to manage.
- It allows the team to focus on developing and improving the application.
- Cloud resources can scale as the application grows.
- The platform provider handles many infrastructure maintenance tasks.
- It supports faster development and deployment.

## Comparison

### IaaS
IaaS provides virtual machines, storage, and networking. It gives the team more control but also requires more responsibility for managing servers and operating systems.

### PaaS
PaaS provides a managed platform for deploying applications. It reduces infrastructure management while still allowing developers to control the application.

### SaaS
SaaS provides a complete software application to users. It would be less suitable for KijaniKiosk because the team is developing and operating its own application rather than simply consuming an existing software product.

## Decision

PaaS is recommended because it provides a balance between application control and reduced infrastructure management, allowing the KijaniKiosk team to focus on delivering the application.
