#!/bin/bash

set -euo pipefail

MODE="${1:-multipass}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"

if [[ "$MODE" != "multipass" && "$MODE" != "cloud" ]]; then
    echo "Usage: $0 [multipass|cloud]"
    exit 1
fi

echo "=== KijaniKiosk IaC Pipeline ==="
echo "Mode: $MODE"

echo
echo "=== Terraform Apply ==="
cd "$TERRAFORM_DIR"
terraform apply -auto-approve

echo
echo "=== Reading Terraform Outputs ==="

if [[ "$MODE" == "multipass" ]]; then
    API_IP=$(multipass info kijanikiosk-api | awk '/IPv4/ {print $2; exit}')
    PAYMENTS_IP=$(multipass info kijanikiosk-payments | awk '/IPv4/ {print $2; exit}')
    LOGS_IP=$(multipass info kijanikiosk-logs | awk '/IPv4/ {print $2; exit}')
else
    API_IP=$(terraform output -json server_ips | jq -r '.api')
    PAYMENTS_IP=$(terraform output -json server_ips | jq -r '.payments')
    LOGS_IP=$(terraform output -json server_ips | jq -r '.logs')
fi

echo "API: $API_IP"
echo "Payments: $PAYMENTS_IP"
echo "Logs: $LOGS_IP"

echo
echo "=== Generating Ansible Inventory ==="

cat > "$ANSIBLE_DIR/inventory.ini" <<EOF
[kijanikiosk]
api ansible_host=$API_IP
payments ansible_host=$PAYMENTS_IP
logs ansible_host=$LOGS_IP

[kijanikiosk:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/multipass_id_rsa
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

cat "$ANSIBLE_DIR/inventory.ini"

echo
echo "=== Running Ansible ==="

cd "$ANSIBLE_DIR"
ansible-playbook -i inventory.ini kijanikiosk.yml

echo
echo "=== Pipeline completed successfully ==="
