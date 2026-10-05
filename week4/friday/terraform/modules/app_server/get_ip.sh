#!/bin/bash

set -euo pipefail

NAME="$1"

IP=$(multipass info "$NAME" | awk '/IPv4/ {print $2; exit}')

printf '{"ip":"%s"}\n' "$IP"

