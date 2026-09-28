# KijaniKiosk Payments Service Hardening

## Hardening Objective

The payments service was hardened using `systemd-analyze security` as the measurement. The goal was to reduce the service's exposure while keeping its health endpoint and normal startup behavior functional.

## Starting Score

The starting exposure score for `kk-payments.service` was **2.7** before the additional hardening changes were applied.

## Hardening Iterations

| Stage | Change | Resulting score | Functional result |
|---|---|---:|---|
| Baseline | Existing production unit before additional hardening | 2.7 | Service started |
| 1 | Added `UMask=0077` | 2.7 | Service started |
| 2 | Added `RemoveIPC=true`, `SystemCallFilter`, restrictive address-family settings and `IPAddressDeny=any` | 0.9 | Service started, but health endpoint failed |
| 3 | Removed `IPAddressDeny=any` | 1.1 | Service started and health endpoint passed |
| Final | Final hardened configuration | **1.1** | **PASS** |

The final score of **1.1** is below the required maximum of **2.5**.

## Directives Retained

| Directive | Purpose |
|---|---|
| `NoNewPrivileges=true` | Prevents the service from gaining additional privileges. |
| `PrivateTmp=true` | Gives the service an isolated temporary directory. |
| `ProtectSystem=strict` | Protects most of the operating system from modification. |
| `ProtectHome=true` | Prevents access to users' home directories. |
| `ProtectKernelTunables=true` | Protects kernel configuration settings. |
| `ProtectKernelModules=true` | Prevents modification of kernel modules. |
| `ProtectControlGroups=true` | Restricts access to control-group management. |
| `RestrictAddressFamilies=AF_INET AF_INET6` | Limits networking to the IP families required by the service. |
| `RestrictNamespaces=true` | Prevents unnecessary namespace creation. |
| `LockPersonality=true` | Prevents changing the execution personality. |
| `MemoryDenyWriteExecute=true` | Restricts memory from being simultaneously writable and executable. |
| `RestrictSUIDSGID=true` | Prevents creation of set-user-ID and set-group-ID files. |
| `SystemCallArchitectures=native` | Restricts system calls to the native architecture. |
| `UMask=0077` | Gives newly created files restrictive default permissions. |
| `ProtectKernelLogs=true` | Prevents access to protected kernel logs. |
| `ProtectClock=true` | Restricts manipulation of system clock settings. |
| `ProtectHostname=true` | Restricts changes to the system hostname. |
| `ProtectProc=invisible` | Limits visibility of other processes. |
| `ProcSubset=pid` | Restricts process information visibility. |
| `PrivateDevices=true` | Restricts access to physical device interfaces. |
| `PrivateUsers=true` | Provides additional user-identity isolation. |
| `CapabilityBoundingSet=` | Removes unnecessary Linux capabilities. |
| `AmbientCapabilities=` | Prevents ambient capabilities from being granted. |
| `RestrictRealtime=true` | Prevents use of real-time scheduling privileges. |
| `PrivateMounts=true` | Gives the service an isolated mount namespace. |
| `ReadWritePaths=/opt/kijanikiosk/shared/logs` | Allows writing only to the required shared logging area. |

## Rejected Directives

### `IPAddressDeny=any`

This directive was initially accepted during testing because it reduced the exposure score from the baseline. However, it blocked the payments health endpoint, which is required for monitoring. The directive was therefore removed. The final score increased from **0.9 to 1.1**, but the service became fully functional and remained below the required **2.5** threshold.

### `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6`

This configuration was tested and rejected because the payments service did not require Unix-domain socket access for its tested workload. The final configuration permits only `AF_INET` and `AF_INET6`, which are sufficient for the service's required network operation.

## Dependency and Environment Configuration

The payments service starts after the API service and declares a dependency on it. This ensures the API component is brought up as part of the payments service dependency chain.

The service also receives its configuration through a dedicated environment file. The file exists before the service is started, is readable by the payments service account, and contains only the values required by the application.

## Complete Final Unit File

```ini
[Unit]
Description=KijaniKiosk Payments
After=kk-api.service
Wants=kk-api.service

[Service]
Type=simple
User=kk-payments
Group=kijanikiosk
EnvironmentFile=/opt/kijanikiosk/config/payments-api.env
ExecStart=/usr/bin/python3 -m http.server 3001 --bind 127.0.0.1
Restart=on-failure
RestartSec=5

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_INET AF_INET6
RestrictNamespaces=true
LockPersonality=true
MemoryDenyWriteExecute=true
RestrictSUIDSGID=true
SystemCallArchitectures=native
UMask=0077
ProtectKernelLogs=true
ProtectClock=true
ProtectHostname=true
ProtectProc=invisible
ProcSubset=pid
PrivateDevices=true
PrivateUsers=true
CapabilityBoundingSet=
AmbientCapabilities=
RestrictRealtime=true
PrivateMounts=true

ReadWritePaths=/opt/kijanikiosk/shared/logs

[Install]
WantedBy=multi-user.target
