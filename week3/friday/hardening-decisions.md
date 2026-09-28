# KijaniKiosk Security Hardening Decisions

## Purpose

KijaniKiosk is designed to provide a dependable production foundation for services that process operational information. The security approach focuses on reducing unnecessary access, limiting the effect of a compromised service, protecting internal communications, and keeping operational records available for investigation.

The decisions below were made with a balance between security and reliability. Strong protection is useful only when the application can still perform its required functions. For that reason, each control was tested after implementation rather than being accepted based only on its theoretical security benefit.

| Control | What it does | Risk mitigated |
|---|---|---|
| ProtectSystem=strict | Makes most of the system unavailable for modification by services. | Reduces unauthorized system changes. |
| ProtectHome=true | Prevents services from accessing users' private home areas. | Limits exposure of personal and administrative information. |
| NoNewPrivileges=true | Prevents a service from gaining additional privileges during execution. | Reduces the impact of service compromise. |
| PrivateDevices=true | Gives services restricted access to physical device interfaces. | Limits misuse of hardware resources. |
| PrivateUsers=true | Separates service identities from privileged system identities. | Reduces the consequences of identity abuse. |
| RestrictAddressFamilies | Limits the types of network communication a service can use. | Reduces unnecessary network exposure. |
| MemoryDenyWriteExecute=true | Prevents memory from being both writable and executable. | Makes some forms of malicious code execution harder. |
| CapabilityBoundingSet= | Removes unnecessary administrative capabilities from services. | Limits privilege escalation opportunities. |
| UMask=0077 | Prevents newly created payment-service files from being broadly accessible. | Reduces accidental disclosure of sensitive data. |
| Firewall rules | Controls which network connections are permitted to the server. | Reduces unauthorized remote access. |
| Default ACLs | Ensures new shared log files inherit the required access permissions. | Prevents logging failures after file rotation. |
| Persistent journal limits | Keeps important operational records while limiting disk consumption. | Reduces loss of evidence and disk exhaustion. |

## Service Protection

Each application component operates under its own dedicated identity. This separates responsibilities and prevents one component from automatically receiving the permissions of another. Access to shared information is granted only where it is required for normal operation.

The payment component receives additional protection because it handles a more sensitive function. Its permissions are deliberately narrower, and its network communication is restricted to what the service requires. This reduces the potential effect of a compromise without preventing the service from responding to its required health checks.

## Network Protection

The server does not expose internal application ports unnecessarily. External access is limited to the services that need to receive traffic, while internal communication remains available to the server itself.

The payment health endpoint is accessible from the designated internal network but is blocked from general external access. This provides a useful monitoring path without making the payment service directly reachable from everywhere.

The application services also listen only on the local server interface. A front-facing web service can therefore handle permitted external traffic while the application processes remain protected from direct outside connections.

## File and Logging Protection

Shared logging requires carefully controlled access because all three service components need to write operational information. The shared area therefore grants writing access to the approved service identities while preventing general users from modifying its contents.

New files inherit the required permissions automatically. This was important because file rotation creates replacement files. The final test confirmed that the API component could still create a file after rotation, demonstrating that the access model continues to work during normal maintenance.

Operational records are retained within a defined storage limit. This helps balance investigation needs with the risk of filling the server's available storage.

## Reliability and Testing

Security controls were tested together with service functionality. The three services successfully started, their health checks returned successful responses, and the required security exposure measurements remained below their assigned limits.

One restrictive network control was tested and rejected because it prevented the payment health check from functioning. Another overly restrictive communication setting was also rejected because the service needed a permitted network family. These decisions demonstrate that the final configuration was based on observed application requirements rather than applying restrictions blindly.

The provisioning process is also designed to handle an already-used server. Existing accounts, directories, package conditions, firewall rules, logging configuration, and service definitions are checked or corrected instead of assuming a completely empty machine. This makes repeated provisioning safer and more predictable.

## Business Risk

The main security benefit is reduced blast radius. If one service is compromised, the attacker does not automatically receive unrestricted access to the operating system, other services, private user information, or protected resources.

There are still operational risks. The system depends on correct application configuration, secure credentials, timely operating-system updates, and appropriate monitoring. The firewall also assumes that the designated internal network is trustworthy and correctly controlled.

## Remaining Gap

This foundation does not eliminate every production security risk. It does not replace application-level authentication, secrets management, vulnerability scanning, intrusion detection, or a full centralized security-monitoring solution. These areas should be addressed before the platform is treated as a complete production security program.
