#!/usr/bin/env bash
set -euo pipefail

# Step 5 - Configure OpenConnect Server
# Usage: ./configure-ocserv.sh <domain> [tcp_port]
# Example: ./configure-ocserv.sh vpn.example.com 443

DOMAIN="${1:?Usage: $0 <domain> [tcp_port]}"
TCP_PORT="${2:-443}"
OCSERV_DIR="${OCSERV_DIR:-/tmp/ocserv}"
CONF="/etc/ocserv/ocserv.conf"

echo "==> Configuring ocserv for domain: ${DOMAIN}, port: ${TCP_PORT}"

# Create config directory
sudo mkdir -p /etc/ocserv

# Copy sample config if not present
if [[ ! -f "${CONF}" ]]; then
    sudo cp "${OCSERV_DIR}/doc/sample.config" "${CONF}"
    echo "==> Copied sample config to ${CONF}"
else
    echo "==> Config already exists at ${CONF}, applying changes in place"
fi

# Auth: use plain password file
sudo sed -i 's|^auth = .*|auth = "plain[passwd=/etc/ocserv/ocpasswd]"|' "${CONF}"

# TCP port
sudo sed -i "s|^tcp-port = .*|tcp-port = ${TCP_PORT}|" "${CONF}"

# Disable UDP port
sudo sed -i 's|^udp-port = .*|#udp-port = 443|' "${CONF}"

# SSL certificate paths
sudo sed -i "s|^server-cert = .*|server-cert = /etc/letsencrypt/live/${DOMAIN}/fullchain.pem|" "${CONF}"
sudo sed -i "s|^server-key = .*|server-key = /etc/letsencrypt/live/${DOMAIN}/privkey.pem|" "${CONF}"

# Max clients
sudo sed -i 's|^max-clients = .*|max-clients = 16|' "${CONF}"

# Max same clients
sudo sed -i 's|^max-same-clients = .*|max-same-clients = 2|' "${CONF}"

# Keepalive (default 32400 -> 60)
sudo sed -i 's|^keepalive = .*|keepalive = 60|' "${CONF}"

# Enable MTU discovery
sudo sed -i 's|^try-mtu-discovery = .*|try-mtu-discovery = true|' "${CONF}"

# Idle timeouts (uncomment and set)
sudo sed -i 's|^#\?idle-timeout=.*|idle-timeout=1200|' "${CONF}"
sudo sed -i 's|^#\?mobile-idle-timeout=.*|mobile-idle-timeout=1800|' "${CONF}"

# Default domain
sudo sed -i "s|^default-domain = .*|default-domain = ${DOMAIN}|" "${CONF}"

# IPv4 network
sudo sed -i 's|^ipv4-network = .*|ipv4-network = 10.10.10.0|' "${CONF}"

# Tunnel all DNS
sudo sed -i 's|^#\?tunnel-all-dns = .*|tunnel-all-dns = true|' "${CONF}"

# DNS resolvers - replace first dns line, add second after it
sudo sed -i '0,/^dns = .*/s|^dns = .*|dns = 8.8.8.8|' "${CONF}"
# Add Google secondary DNS if not already present
if ! grep -q 'dns = 8.8.4.4' "${CONF}"; then
    sudo sed -i '/^dns = 8.8.8.8/a dns = 8.8.4.4' "${CONF}"
fi

# Comment out route lines
sudo sed -i 's|^route = |#route = |' "${CONF}"
sudo sed -i 's|^no-route = |#no-route = |' "${CONF}"

echo "==> ocserv configuration complete: ${CONF}"
