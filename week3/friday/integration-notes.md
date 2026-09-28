# KijaniKiosk Integration Notes

## Systemd and Environment Files

The three services use dedicated service accounts and separate environment files. The provisioning process creates the required files before starting the services and verifies their readability.

Payments explicitly starts after the API service and declares a dependency on it.

## Systemd Hardening and Functionality

Security restrictions were applied while preserving the services' required functions. The payments service initially achieved a very low security score after applying a network-denial restriction, but that restriction prevented its health endpoint from responding.

The restriction was removed and the final payments score became 1.1 while the health endpoint remained functional.

## Logrotate and Service Isolation

The shared log directory uses group ownership and default ACLs so replacement files retain the required access permissions.

The logging service uses a private temporary directory and does not define a reload operation. The provisioning process therefore uses service restart behavior after rotation rather than assuming a reload operation exists.

The provisioning process performs a forced rotation and verifies that `kk-api` can write to the shared logs directory afterward.

## Firewall

The firewall is reset to a known baseline on every provisioning run. SSH, HTTP, and the internal payments health endpoint are permitted from the required internal network.

The payments port is denied externally while loopback traffic remains available for local service communication and proxying.

## Journald

Persistent journal storage is enabled with bounded disk usage and retention settings. This prevents uncontrolled journal growth while retaining recent operational information.

## Dirty-State Remediation

The project was intentionally tested against an existing installation containing conflicting accounts, a weak existing service unit, an unwanted firewall rule, an unsafe configuration permission, a package hold, and an incomplete logrotate configuration.

The provisioning process detected and remediated the dirty state without requiring a manual cleanup.

A subsequent clean rerun completed successfully, demonstrating idempotent behavior.

## Remaining Integration Gap

The current service health endpoints are local test endpoints used to validate the production foundation. Full application deployment, external TLS termination, centralized monitoring, and production credentials would still be required before a real public production deployment.
