# KijaniKiosk Access Model

## Purpose

The access model gives each production service only the permissions it needs while allowing the services to work together through a shared logging area.

## Service Accounts

KijaniKiosk uses three dedicated non-login service accounts:

- `kk-api` — runs the API service.
- `kk-payments` — runs the payments service.
- `kk-logs` — runs the logging service.

All three accounts belong to the shared `kijanikiosk` group.

## Directory Access

The application configuration area is owned by root and shared with the service group. Service accounts have read access to the configuration files they require.

The shared logs directory is owned by the `kijanikiosk` group. The three service accounts can write to this directory.

The shared directory uses the set-group-ID permission so newly created files and directories retain the intended group ownership.

## Default ACLs

Default ACLs are applied to the shared logs directory. This ensures that permissions continue to apply to newly created log files.

This is important because logrotate creates replacement files during rotation. The access model therefore survives rotation instead of requiring manual permission repairs.

## Logrotate Verification

The provisioning process forces an actual log rotation and then verifies that `kk-api` can still create a file in the shared logs directory.

The required verification produced:

`PASS: kk-api can write after logrotate`

## Environment Files

Each service has its own environment file. The files are owned by root and readable by the appropriate service accounts through the shared group.

The provisioning process verifies that all three environment files are readable.

## Security Principle

The model follows least privilege: services run under dedicated accounts instead of root, shared access is limited to the required locations, and configuration ownership remains under administrative control.
