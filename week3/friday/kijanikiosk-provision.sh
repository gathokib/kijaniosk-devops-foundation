#!/usr/bin/env bash
set -euo pipefail

# KijaniKiosk Production Server Foundation
# Week 3 Friday provisioning script
#
# Dirty-state conditions intentionally tested:
# 1. Existing service accounts
# 2. Incorrect configuration permissions
# 3. Existing/incomplete logrotate configuration
# 4. Existing unwanted UFW rule
# 5. Held package
# 6. Existing weak systemd unit
#
# The script is designed to be idempotent: it can be run repeatedly
# without creating duplicate users, rules, configuration, or units.

LOG_FILE="${LOG_FILE:-/var/log/kijanikiosk-provision.log}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

fail() {
    log "ERROR: $*"
    exit 1
}

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this script with sudo."
    exit 1
fi

exec > >(tee -a "$LOG_FILE") 2>&1

log "===== KIJANIKIOSK PROVISIONING START ====="
log "Host: $(hostname)"
log "Date: $(date)"
# =========================
# PHASE 1: PREFLIGHT
# =========================

log "PHASE 1: Preflight and dirty-state handling"

# Service accounts: create only if missing.
for user in kk-api kk-payments kk-logs; do
    if getent passwd "$user" >/dev/null; then
        log "DIRTY STATE: $user already exists; preserving account."
    else
        log "Creating missing service account: $user"
        useradd --system --shell /usr/sbin/nologin "$user"
    fi
done

# Shared group: create only if missing.
if getent group kijanikiosk >/dev/null; then
    log "kijanikiosk group already exists; preserving it."
else
    log "Creating kijanikiosk group."
    groupadd --system kijanikiosk
fi

# Ensure service accounts belong to the shared group.
for user in kk-api kk-payments kk-logs; do
    usermod -aG kijanikiosk "$user"
done

# Required directory structure.
mkdir -p /opt/kijanikiosk/config
mkdir -p /opt/kijanikiosk/shared/logs
mkdir -p /opt/kijanikiosk/health

log "PHASE 1 complete"
# =========================
# PHASE 2: PACKAGES & CONFIGURATION
# =========================

log "PHASE 2: Packages and configuration"

REQUIRED_PACKAGES=(
    acl
    curl
    jq
    logrotate
    nginx
    ufw
)

for package in "${REQUIRED_PACKAGES[@]}"; do
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
        log "Package already installed: $package"
    else
        log "Installing package: $package"
        apt-get install -y "$package"
    fi
done

# Handle dirty package holds explicitly.
if apt-mark showhold | grep -qx "curl"; then
    log "DIRTY STATE: curl is held; removing hold before package verification."
    apt-mark unhold curl
fi

# Record the installed package versions used by this environment.
{
    echo "KijaniKiosk package versions"
    echo "nginx: $(dpkg-query -W -f='${Version}' nginx)"
    echo "curl: $(dpkg-query -W -f='${Version}' curl)"
    echo "logrotate: $(dpkg-query -W -f='${Version}' logrotate)"
    echo "acl: $(dpkg-query -W -f='${Version}' acl)"
    echo "ufw: $(dpkg-query -W -f='${Version}' ufw)"
    echo "jq: $(dpkg-query -W -f='${Version}' jq)"
} > /opt/kijanikiosk/config/package-versions.txt

chmod 640 /opt/kijanikiosk/config/package-versions.txt
chown root:kijanikiosk /opt/kijanikiosk/config/package-versions.txt

log "Package installation and verification complete."
log "PHASE 2 complete"
# =========================
# PHASE 3: ACCESS MODEL
# =========================

log "PHASE 3: Users, directories, permissions and ACLs"

# Root owns the application tree.
chown root:root /opt/kijanikiosk

# Shared group owns writable application areas.
chown root:kijanikiosk /opt/kijanikiosk/shared
chown root:kijanikiosk /opt/kijanikiosk/shared/logs
chown root:kijanikiosk /opt/kijanikiosk/config
chown root:kijanikiosk /opt/kijanikiosk/config/package-versions.txt
chmod 640 /opt/kijanikiosk/config/package-versions.txt
chown root:kijanikiosk /opt/kijanikiosk/health

# Remove the intentionally dirty 777 configuration permissions.
chmod 750 /opt/kijanikiosk/config
chmod 2770 /opt/kijanikiosk/shared
chmod 2770 /opt/kijanikiosk/shared/logs
chmod 2750 /opt/kijanikiosk/health

# Service accounts need access to their configuration and shared logs.
setfacl -m u:kk-api:rx,u:kk-payments:rx,u:kk-logs:rx /opt/kijanikiosk/config

# Shared logs: services can read/write, and the group ownership is inherited.
setfacl -m u:kk-api:rwx,u:kk-payments:rwx,u:kk-logs:rwx /opt/kijanikiosk/shared/logs
setfacl -d -m g:kijanikiosk:rwx /opt/kijanikiosk/shared/logs
setfacl -d -m u:kk-api:rwx,u:kk-payments:rwx,u:kk-logs:rwx /opt/kijanikiosk/shared/logs

# Health directory: services can read the health information.
setfacl -m u:kk-api:rx,u:kk-payments:rx,u:kk-logs:rx /opt/kijanikiosk/health

log "Access model applied."

# Verify the critical access model using the intended service group
runuser -u kk-api -g kijanikiosk -- test -r /opt/kijanikiosk/config/package-versions.txt
runuser -u kk-api -g kijanikiosk -- test -w /opt/kijanikiosk/shared/logs
runuser -u kk-payments -g kijanikiosk -- test -w /opt/kijanikiosk/shared/logs
runuser -u kk-logs -g kijanikiosk -- test -w /opt/kijanikiosk/shared/logs

log "Access verification passed."
log "PHASE 3 complete"
# =========================
# PHASE 4: SYSTEMD SERVICES
# =========================

log "PHASE 4: Creating hardened systemd services"

# Handle dirty existing units explicitly.
for unit in kk-api.service kk-payments.service kk-logs.service; do
    if [[ -f "/etc/systemd/system/$unit" ]]; then
        log "DIRTY STATE: existing $unit detected; replacing with managed unit."
    else
        log "Creating missing $unit."
    fi
done

# API service
cat > /etc/systemd/system/kk-api.service <<'EOF'
[Unit]
Description=KijaniKiosk API
After=network.target

[Service]
Type=simple
User=kk-api
Group=kijanikiosk
EnvironmentFile=/opt/kijanikiosk/config/api.env
ExecStart=/usr/bin/python3 -m http.server 3000 --bind 127.0.0.1
Restart=on-failure
RestartSec=5

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictNamespaces=true
LockPersonality=true
MemoryDenyWriteExecute=true
RestrictSUIDSGID=true
SystemCallArchitectures=native
UMask=0027
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
RestrictSUIDSGID=true

ReadWritePaths=/opt/kijanikiosk/shared/logs

[Install]
WantedBy=multi-user.target
EOF

# Payments service
cat > /etc/systemd/system/kk-payments.service <<'EOF'
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
PrivateMounts=true
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
RestrictRealtime=true
CapabilityBoundingSet=
AmbientCapabilities=
RestrictRealtime=true
RestrictSUIDSGID=true
RemoveIPC=true
SystemCallFilter=~@clock @cpu-emulation @debug @module @mount @obsolete @privileged @raw-io @reboot @resources @swap

ReadWritePaths=/opt/kijanikiosk/shared/logs

[Install]
WantedBy=multi-user.target
EOF

# Logs service
cat > /etc/systemd/system/kk-logs.service <<'EOF'
[Unit]
Description=KijaniKiosk Logs
After=network.target

[Service]
Type=simple
User=kk-logs
Group=kijanikiosk
EnvironmentFile=/opt/kijanikiosk/config/logs.env
ExecStart=/usr/bin/python3 -m http.server 3002 --bind 127.0.0.1
Restart=on-failure
RestartSec=5

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictNamespaces=true
LockPersonality=true
MemoryDenyWriteExecute=true
RestrictSUIDSGID=true
SystemCallArchitectures=native
UMask=0027
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
RestrictSUIDSGID=true

ReadWritePaths=/opt/kijanikiosk/shared/logs

[Install]
WantedBy=multi-user.target
EOF

# Required EnvironmentFile paths.
cat > /opt/kijanikiosk/config/api.env <<'EOF'
KK_SERVICE=api
KK_PORT=3000
EOF

cat > /opt/kijanikiosk/config/payments-api.env <<'EOF'
KK_SERVICE=payments
KK_PORT=3001
EOF

cat > /opt/kijanikiosk/config/logs.env <<'EOF'
KK_SERVICE=logs
KK_PORT=3002
EOF

chown root:kijanikiosk /opt/kijanikiosk/config/*.env
chmod 640 /opt/kijanikiosk/config/*.env

systemctl daemon-reload

systemctl enable kk-api.service kk-payments.service kk-logs.service

systemctl restart kk-api.service
systemctl restart kk-payments.service
systemctl restart kk-logs.service

systemctl is-active --quiet kk-api.service
systemctl is-active --quiet kk-payments.service
systemctl is-active --quiet kk-logs.service

log "All three systemd services started successfully."

log "systemd security scores:"
systemd-analyze security kk-api.service | tail -1 || true
systemd-analyze security kk-payments.service | tail -1 || true
systemd-analyze security kk-logs.service | tail -1 || true

log "PHASE 4 complete"
# =========================
# PHASE 5: FIREWALL
# =========================

log "PHASE 5: Resetting and configuring UFW"

# Reset to a known baseline instead of modifying the dirty state incrementally.
ufw --force reset

# Loopback must be allowed before the explicit external deny for port 3001.
ufw allow in on lo comment 'Allow loopback traffic'

# SSH, HTTP and the payments health endpoint are allowed only from the
# required internal source network.
ufw allow from 10.0.1.0/24 to any port 22 proto tcp comment 'Allow SSH from internal network'
ufw allow from 10.0.1.0/24 to any port 80 proto tcp comment 'Allow HTTP from internal network'
ufw allow from 10.0.1.0/24 to any port 3001 proto tcp comment 'Allow payments health from internal network'

# Port 3001 must not be reachable externally.
ufw deny in 3001/tcp comment 'Deny external payments port'

# Explicitly deny the other application ports externally.
ufw deny in 3000/tcp comment 'Deny external API port'
ufw deny in 3002/tcp comment 'Deny external logs port'

ufw --force enable

log "UFW rules configured."

# Programmatic rule verification.
ufw status | grep -q "22/tcp.*10.0.1.0/24" \
    || fail "Missing SSH rule."

ufw status | grep -q "80/tcp.*10.0.1.0/24" \
    || fail "Missing HTTP rule."

ufw status | grep -q "3001/tcp.*10.0.1.0/24" \
    || fail "Missing payments health rule."

ufw status | grep -q "3001/tcp.*DENY" \
    || fail "Missing external payments deny rule."

ufw status | grep -q "3000/tcp.*DENY" \
    || fail "Missing external API deny rule."

ufw status | grep -q "3002/tcp.*DENY" \
    || fail "Missing external logs deny rule."

log "UFW programmatic verification passed."
log "PHASE 5 complete"
# =========================
# PHASE 6: LOGROTATE
# =========================

log "PHASE 6: Configuring logrotate and persistent access"

cat > /etc/logrotate.d/kijanikiosk <<'EOF'
/opt/kijanikiosk/shared/logs/*.log {
    daily
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    create 0660 kk-logs kijanikiosk
    su kk-logs kijanikiosk
    sharedscripts
    postrotate
        systemctl restart kk-logs.service >/dev/null 2>&1 || true
    endscript
}
EOF

chmod 644 /etc/logrotate.d/kijanikiosk

# Re-apply the default ACL because logrotate can create replacement files.
setfacl -d -m g:kijanikiosk:rwx /opt/kijanikiosk/shared/logs
setfacl -d -m u:kk-api:rwx,u:kk-payments:rwx,u:kk-logs:rwx /opt/kijanikiosk/shared/logs

# Create a real log file so rotation can be tested.
touch /opt/kijanikiosk/shared/logs/kijanikiosk.log
chown kk-logs:kijanikiosk /opt/kijanikiosk/shared/logs/kijanikiosk.log
chmod 660 /opt/kijanikiosk/shared/logs/kijanikiosk.log

log "Testing logrotate configuration."
logrotate -d /etc/logrotate.d/kijanikiosk

log "Forcing log rotation."
logrotate -f /etc/logrotate.d/kijanikiosk

# Definitive required access test.
if sudo -u kk-api touch /opt/kijanikiosk/shared/logs/test-write.tmp; then
    echo "PASS: kk-api can write after logrotate"
else
    echo "FAIL: kk-api cannot write to shared/logs"
    exit 1
fi

rm -f /opt/kijanikiosk/shared/logs/test-write.tmp

log "Logrotate access persistence verified."
log "PHASE 6 complete"
# =========================
# PHASE 7: JOURNAL PERSISTENCE
# =========================

log "PHASE 7: Configuring persistent journald storage"

mkdir -p /var/log/journal
chmod 2755 /var/log/journal

mkdir -p /etc/systemd/journald.conf.d

cat > /etc/systemd/journald.conf.d/kijanikiosk.conf <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=500M
RuntimeMaxUse=100M
MaxRetentionSec=30day
Compress=yes
EOF

systemctl restart systemd-journald

# Verify persistent journal storage.
if [[ -d /var/log/journal ]]; then
    log "Persistent journal directory exists."
else
    fail "Persistent journal directory was not created."
fi

# Verify the journald configuration.
grep -q '^Storage=persistent' /etc/systemd/journald.conf.d/kijanikiosk.conf \
    || fail "Persistent journald storage is not configured."

grep -q '^SystemMaxUse=500M' /etc/systemd/journald.conf.d/kijanikiosk.conf \
    || fail "Journal size limit is missing."

log "Current journal disk usage:"
journalctl --disk-usage

log "PHASE 7 complete"
# =========================
# PHASE 8: MONITORING & FINAL VERIFICATION
# =========================

log "PHASE 8: Monitoring and final verification"

HEALTH_DIR="/opt/kijanikiosk/health"
HEALTH_FILE="$HEALTH_DIR/last-provision.json"

mkdir -p "$HEALTH_DIR"

check_passed=true

check_service() {
    local service="$1"

    if systemctl is-active --quiet "$service"; then
        log "PASS: $service is active"
        return 0
    else
        log "FAIL: $service is not active"
        check_passed=false
        return 1
    fi
}

check_service kk-api.service
check_service kk-payments.service
check_service kk-logs.service

# Check the local health endpoints.
if curl -fsS http://127.0.0.1:3000 >/dev/null; then
    log "PASS: API health endpoint"
else
    log "FAIL: API health endpoint"
    check_passed=false
fi

if curl -fsS http://127.0.0.1:3001 >/dev/null; then
    log "PASS: Payments health endpoint"
else
    log "FAIL: Payments health endpoint"
    check_passed=false
fi

if curl -fsS http://127.0.0.1:3002 >/dev/null; then
    log "PASS: Logs health endpoint"
else
    log "FAIL: Logs health endpoint"
    check_passed=false
fi

# Check the required access model.
if sudo -u kk-api touch /opt/kijanikiosk/shared/logs/final-write-test.tmp; then
    log "PASS: kk-api can write to shared logs"
    rm -f /opt/kijanikiosk/shared/logs/final-write-test.tmp
else
    log "FAIL: kk-api cannot write to shared logs"
    check_passed=false
fi

# Verify environment files.
for env_file in api.env payments-api.env logs.env; do
    if [[ -r "/opt/kijanikiosk/config/$env_file" ]]; then
        log "PASS: Environment file readable: $env_file"
    else
        log "FAIL: Environment file missing/unreadable: $env_file"
        check_passed=false
    fi
done

# Verify firewall is active.
if ufw status | grep -q "Status: active"; then
    log "PASS: UFW is active"
else
    log "FAIL: UFW is not active"
    check_passed=false
fi

# Capture systemd security scores.
API_SCORE=$(systemd-analyze security kk-api.service 2>/dev/null | grep -oP 'Overall exposure level for .*: \K[0-9.]+')
PAYMENTS_SCORE=$(systemd-analyze security kk-payments.service 2>/dev/null | grep -oP 'Overall exposure level for .*: \K[0-9.]+')
LOGS_SCORE=$(systemd-analyze security kk-logs.service 2>/dev/null | grep -oP 'Overall exposure level for .*: \K[0-9.]+')

log "Security scores:"
log "kk-api: ${API_SCORE:-unknown}"
log "kk-payments: ${PAYMENTS_SCORE:-unknown}"
log "kk-logs: ${LOGS_SCORE:-unknown}"

# Validate score thresholds.
if [[ -n "${API_SCORE:-}" ]] && awk "BEGIN {exit !($API_SCORE < 3.5)}"; then
    log "PASS: kk-api security score is below 3.5"
else
    log "FAIL: kk-api security score is not below 3.5"
    check_passed=false
fi

if [[ -n "${PAYMENTS_SCORE:-}" ]] && awk "BEGIN {exit !($PAYMENTS_SCORE < 2.5)}"; then
    log "PASS: kk-payments security score is below 2.5"
else
    log "FAIL: kk-payments security score is not below 2.5"
    check_passed=false
fi

if [[ -n "${LOGS_SCORE:-}" ]] && awk "BEGIN {exit !($LOGS_SCORE < 3.5)}"; then
    log "PASS: kk-logs security score is below 3.5"
else
    log "FAIL: kk-logs security score is not below 3.5"
    check_passed=false
fi

# Write machine-readable health status.
if [[ "$check_passed" == true ]]; then
    STATUS="PASS"
else
    STATUS="FAIL"
fi

cat > "$HEALTH_FILE" <<EOF
{
  "status": "$STATUS",
  "timestamp": "$(date --iso-8601=seconds)",
  "host": "$(hostname)",
  "services": {
    "kk-api": "$(systemctl is-active kk-api.service || true)",
    "kk-payments": "$(systemctl is-active kk-payments.service || true)",
    "kk-logs": "$(systemctl is-active kk-logs.service || true)"
  },
  "security_scores": {
    "kk-api": "${API_SCORE:-unknown}",
    "kk-payments": "${PAYMENTS_SCORE:-unknown}",
    "kk-logs": "${LOGS_SCORE:-unknown}"
  }
}
EOF

chown root:kijanikiosk "$HEALTH_FILE"
chmod 640 "$HEALTH_FILE"

jq empty "$HEALTH_FILE" || fail "Health JSON is invalid."

if [[ "$check_passed" == true ]]; then
    log "===== PROVISIONING PASSED ====="
    exit 0
else
    log "===== PROVISIONING FAILED ====="
    exit 1
fi
