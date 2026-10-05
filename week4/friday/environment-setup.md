# KijaniKiosk Week 4 Environment Setup

## Deployment Path

The primary deployment path for this project uses Terraform with local Multipass Ubuntu 22.04 servers and an S3-compatible MinIO remote backend.

Three application servers are provisioned:

- `kijanikiosk-api`
- `kijanikiosk-payments`
- `kijanikiosk-logs`

Terraform uses a reusable `app_server` module with `for_each` so the same module provisions all three servers.

## Infrastructure

The servers use the following configuration:

| Server | CPUs | Memory | Disk | Role |
|---|---:|---:|---:|---|
| API | 2 | 2 GB | 10 GB | API service |
| Payments | 2 | 2 GB | 10 GB | Payments service |
| Logs | 1 | 1 GB | 10 GB | Logging service |

Ubuntu 22.04 is used for all servers.

Terraform outputs the server names, dynamically discovered IPv4 addresses, and SSH commands.

## Remote State

Terraform state is stored remotely in the MinIO bucket:

`kijanikiosk-tfstate`

The state object is:

`terraform.tfstate`

The MinIO S3 endpoint is:

`http://localhost:9000`

The MinIO service is intentionally kept running with persistent storage so that Terraform state remains available between pipeline executions.

The assignment's primary path uses MinIO. MinIO's S3-compatible backend does not provide the same native state-locking mechanism as some cloud Terraform backends. This limitation is documented rather than hidden.

For a production deployment, state locking should use a backend with supported locking, such as AWS S3 with DynamoDB-based locking, Google Cloud Storage locking, or another supported state-management solution.

## SSH

The Multipass SSH key is stored locally at:

`~/.ssh/multipass_id_rsa`

The same SSH identity is referenced by Ansible through `group_vars/kijanikiosk.yml`.

Ansible dynamically receives the three server addresses from the Terraform pipeline rather than relying on manually maintained server addresses.

## Ansible

Ansible configures each server from a clean Ubuntu installation.

The playbook implements:

1. Required packages
2. Service accounts
3. Directory structure
4. Access-control lists
5. Environment files
6. Systemd services and hardening
7. UFW firewall configuration
8. Persistent journaling
9. Log rotation

Server-specific values are stored in `host_vars`, while shared configuration is stored in `group_vars`.

Templates are used for systemd units, environment files, journald configuration, and logrotate configuration.

## Pipeline

`pipeline.sh` provides the integration between Terraform and Ansible.

The pipeline:

1. Runs Terraform apply.
2. Obtains the current Multipass IP addresses.
3. Generates `ansible/inventory.ini`.
4. Runs the Ansible playbook.
5. Exits with a non-zero status if Terraform or Ansible fails.

The pipeline can be run using:

`./pipeline.sh multipass`

A cloud mode is also supported by the script structure for future deployment expansion.

## Verification

The first complete pipeline run completed successfully.

The second complete pipeline run also completed successfully.

Terraform subsequently reported:

`No changes. Your infrastructure matches the configuration.`

Ansible reported `changed=0` for API, payments, and logs on the idempotency run.

The `kk-payments` systemd security exposure score was reduced to approximately 1.2, below the required 2.5 threshold.
