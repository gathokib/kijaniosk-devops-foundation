# KijaniKiosk Hardening Decisions

## Purpose

The KijaniKiosk infrastructure is designed for Nia, who is responsible for operating a small production-oriented application environment. The hardening approach focuses on reducing unnecessary privileges, limiting access between services, protecting operating-system resources, and making configuration repeatable through infrastructure as code.

Security controls are implemented through Terraform and Ansible so that the desired security posture can be reproduced consistently rather than relying on manual server configuration.

## Security Controls

| Control | What it does | Risk mitigated |
|---|---|---|
| Terraform security groups / network restrictions | Restricts which network traffic can reach infrastructure resources. SSH access should be limited to trusted administrative sources. | Reduces unauthorized network access and exposed management services. |
| Key pair management | Uses an SSH key rather than password-based authentication for server administration. The same controlled identity is referenced by the infrastructure configuration and Ansible. | Reduces password guessing and unauthorized administrative access. |
| Remote Terraform state | Stores infrastructure state remotely instead of relying only on a local state file. | Reduces the risk of losing infrastructure state and improves consistency between deployment runs. |
| State locking | Prevents multiple infrastructure operations from modifying state simultaneously when supported by the selected backend. | Reduces state corruption caused by concurrent infrastructure changes. |
| Dedicated service accounts | API, payments, and logging services run under separate non-root identities. | Limits the impact of a compromised service and prevents unnecessary administrative privileges. |
| Least-privilege filesystem access | Service accounts receive access only to the directories required by the application. | Reduces unauthorized modification or reading of application data. |
| NoNewPrivileges | Prevents a service from gaining additional privileges during execution. | Limits privilege escalation after service compromise. |
| ProtectSystem=strict | Makes the operating-system filesystem hierarchy read-only to the service except for explicitly permitted locations. | Reduces the ability of a compromised service to modify system files. |
| ProtectHome | Prevents service access to user home directories. | Protects user files and credentials from service compromise. |
| PrivateTmp | Gives the service an isolated temporary filesystem. | Reduces exposure to files created by unrelated processes. |
| PrivateDevices | Prevents unnecessary access to hardware devices. | Reduces the attack surface associated with device access. |
| CapabilityBoundingSet | Removes unnecessary Linux capabilities from service processes. | Reduces the privileges available if the service is compromised. |
| RestrictAddressFamilies | Limits the types of network sockets available to the service. | Reduces unnecessary networking capabilities. |
| RestrictNamespaces | Prevents the service from creating additional namespaces. | Reduces opportunities for isolation bypass and container-like privilege escalation. |
| MemoryDenyWriteExecute | Prevents memory from being simultaneously writable and executable. | Makes several classes of memory-based exploitation more difficult. |
| SystemCallArchitectures | Restricts system calls to the native system architecture. | Reduces exposure to incompatible or unnecessary system-call interfaces. |
| UMask | Restricts default permissions assigned to newly created files. | Reduces accidental exposure of application-created files. |
| UFW firewall | Denies unsolicited incoming connections while allowing required administrative access. | Reduces the number of reachable network services. |
| Persistent journaling | Retains system journal information beyond volatile runtime storage. | Improves operational visibility and supports investigation after failures. |
| Log rotation | Controls the growth of application logs and retains historical logs for a defined period. | Prevents uncontrolled log growth from consuming disk space. |

## Systemd Hardening

The payments service receives the strongest service-level hardening because it is an important application component and was specifically evaluated during Week 3.

The service runs as `kk-payments` instead of root. It has no ambient capabilities and an empty capability bounding set. It also uses `NoNewPrivileges`, `PrivateTmp`, `PrivateDevices`, `PrivateUsers`, and `PrivateMounts`.

Filesystem protection is provided through `ProtectSystem=strict` and `ProtectHome`. The service is explicitly allowed to write only to the application log location. Its environment file remains readable because it is located in the application configuration directory and is accessible to the service account.

Network access is restricted using `RestrictAddressFamilies` so the service can use normal IPv4 and IPv6 communication without being given access to unnecessary socket families.

Additional restrictions include `RestrictNamespaces`, `LockPersonality`, `MemoryDenyWriteExecute`, `RestrictSUIDSGID`, `ProtectKernelLogs`, `ProtectClock`, `ProtectHostname`, `ProtectProc`, `ProcSubset`, and `RestrictRealtime`.

System-call filtering was also added to reduce access to unnecessary system-call groups. An earlier attempt to deny all IP addresses was rejected because it interfered with the application's health behavior. This demonstrates that hardening must balance security with application functionality rather than blindly enabling every available restriction.

## Network Security

The local Multipass environment does not provide the same cloud security-group model as a public cloud platform. UFW therefore provides the primary host-level network control. Incoming traffic is denied by default, outgoing traffic is allowed, and SSH is explicitly permitted for administration.

For a cloud deployment, the equivalent Terraform security-group configuration should permit SSH only from the administrator's current trusted source rather than from the entire internet.

## Verification

The final `kk-payments` service security exposure score is approximately 1.2, which is below the required 2.5 threshold.

The infrastructure and configuration were also tested for repeatability. Terraform reports no infrastructure changes after the initial deployment, while Ansible reports zero changed hosts on a second configuration run.

## Remaining Risk

The current posture does not protect the environment against every threat. It does not eliminate vulnerabilities in the application itself, compromised administrator credentials, malicious or vulnerable dependencies, supply-chain attacks, or attacks originating from a trusted administrative workstation. It also does not provide centralized security monitoring or a full intrusion-detection capability. Production deployment should therefore add centralized logging, monitoring, vulnerability management, stronger identity controls, protected secret management, and a backend with supported state locking.
