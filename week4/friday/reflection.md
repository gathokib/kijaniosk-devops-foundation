# Week 4 Reflection

This week's work connected the infrastructure and configuration-management stages into a repeatable deployment pipeline.

The most important lesson was the value of separating infrastructure provisioning from server configuration. Terraform is responsible for creating the three servers, while Ansible applies the operating-system and application configuration. The pipeline then connects the two stages by generating the Ansible inventory from the infrastructure outputs.

A major challenge was working with the local Multipass environment while still designing the solution around infrastructure-as-code principles. Instead of hardcoding server addresses, the pipeline discovers the current addresses and generates the inventory dynamically.

Another important lesson was idempotency. The pipeline was executed twice successfully. Terraform reported no infrastructure changes on the subsequent plan, and Ansible reported `changed=0` for all three servers. This demonstrates that the deployment can be repeated without unnecessarily modifying an already-correct environment.

The security work also showed that hardening requires testing rather than simply adding restrictions. The payments service initially had a higher security exposure score. Additional systemd restrictions reduced the final score to approximately 1.2. Some restrictions were rejected because they interfered with application health behavior.

The main limitation of the current implementation is the local MinIO backend. It provides persistent remote state for this project, but its state-locking capabilities do not provide the same production guarantees as a cloud backend with supported locking. A production implementation should use a backend designed for reliable collaborative state management.

Overall, Week 4 transformed the previous manual server-foundation work into a reproducible IaC workflow. The resulting pipeline can provision infrastructure, generate dynamic inventory, configure servers, apply security controls, and verify idempotency.
