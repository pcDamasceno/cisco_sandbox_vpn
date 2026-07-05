#!/usr/bin/env bash
set -euo pipefail

# Step 9 - Configure IP Masquerading in UFW
# Usage: ./configure-ufw-masquerade.sh [interface]
# If no interface given, auto-detects the default route interface.

IFACE="${1:-}"
UFW_RULES="/etc/ufw/before.rules"
VPN_SUBNET="10.10.10.0/24"

if [[ -z "${IFACE}" ]]; then
    IFACE=$(ip route show default | awk '{print $5; exit}')
    echo "==> Auto-detected interface: ${IFACE}"
fi

if [[ -z "${IFACE}" ]]; then
    echo "ERROR: Could not detect network interface. Pass it as argument."
    exit 1
fi

echo "==> Configuring IP masquerading on ${IFACE} for ${VPN_SUBNET}"

# --- Add NAT rules at end of before.rules if not already present ---
if ! grep -q "POSTROUTING.*${VPN_SUBNET}.*MASQUERADE" "${UFW_RULES}"; then
    cat <<EOF | sudo tee -a "${UFW_RULES}" > /dev/null

# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s ${VPN_SUBNET} -o ${IFACE} -j MASQUERADE

# End each table with the 'COMMIT' line or these rules won't be processed
COMMIT
EOF
    echo "==> Added NAT masquerade rules"
else
    echo "==> NAT masquerade rules already present, skipping"
fi

# --- Add forwarding rules after icmp echo-request if not already present ---
if ! grep -q "ufw-before-forward.*${VPN_SUBNET}.*ACCEPT" "${UFW_RULES}"; then
    sudo sed -i "/-A ufw-before-forward -p icmp --icmp-type echo-request -j ACCEPT/a\\
# allow forwarding for trusted network\\
-A ufw-before-forward -s ${VPN_SUBNET} -j ACCEPT\\
-A ufw-before-forward -d ${VPN_SUBNET} -j ACCEPT" "${UFW_RULES}"
    echo "==> Added forwarding rules for ${VPN_SUBNET}"
else
    echo "==> Forwarding rules already present, skipping"
fi

echo "==> Restarting UFW"
sudo systemctl restart ufw

echo "==> Verifying masquerade rule:"
sudo iptables -t nat -L POSTROUTING
