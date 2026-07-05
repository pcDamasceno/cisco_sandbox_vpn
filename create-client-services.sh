#!/usr/bin/env bash
set -euo pipefail

# Step 10 - Create OpenConnect client systemd services
# Usage: ./create-client-services.sh <domain> <username> <password>

DOMAIN="${1:?Usage: $0 <domain> <username> <password>}"
USERNAME="${2:?Usage: $0 <domain> <username> <password>}"
PASSWORD="${3:?Usage: $0 <domain> <username> <password>}"

echo "==> Creating OpenConnect client systemd services"

# --- Main VPN service ---
sudo tee /etc/systemd/system/openconnect.service > /dev/null <<EOF
[Unit]
Description=OpenConnect VPN Client
After=network-online.target systemd-resolved.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash -c '/bin/echo -n ${PASSWORD} | /usr/sbin/openconnect ${DOMAIN} -u ${USERNAME} --passwd-on-stdin'
KillSignal=SIGINT
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
echo "==> Created openconnect.service"

# --- Suspend/resume restart service ---
sudo tee /etc/systemd/system/openconnect-restart.service > /dev/null <<EOF
[Unit]
Description=Restart OpenConnect client when resuming from suspend
After=suspend.target

[Service]
Type=simple
ExecStart=/bin/systemctl --no-block restart openconnect.service

[Install]
WantedBy=suspend.target
EOF
echo "==> Created openconnect-restart.service"

# --- Connection health check service ---
sudo tee /etc/systemd/system/openconnect-check.service > /dev/null <<EOF
[Unit]
Description=OpenConnect VPN Connectivity Checker
After=openconnect.service

[Service]
Type=simple
ExecStart=/bin/bash -c 'for ((; ; )) do (ping -c9 10.10.10.1 || systemctl restart openconnect) done'

[Install]
WantedBy=multi-user.target
EOF
echo "==> Created openconnect-check.service"

# --- Enable services ---
sudo systemctl daemon-reload
sudo systemctl enable openconnect.service
sudo systemctl enable openconnect-restart.service
sudo systemctl enable openconnect-check.service

echo "==> All client services created and enabled"
echo "==> Start with: sudo systemctl start openconnect && sudo systemctl start openconnect-check"
