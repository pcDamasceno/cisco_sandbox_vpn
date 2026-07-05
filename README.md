# VPN Setup (OpenConnect / ocserv)

Automated setup for a self-hosted OpenConnect VPN. The **server** side builds and
configures [`ocserv`](https://gitlab.com/openconnect/ocserv) with a Let's Encrypt
certificate; the **client** side installs `openconnect` and connects.

Everything is driven by `make`, so you clone the repo and run a few targets — either
passing values inline or exporting them as environment variables.

---

## Repository contents

| File | Purpose |
| --- | --- |
| `Makefile` | **Client** targets (install `openconnect`, connect / disconnect). |
| `Makefile_server` | **Server** targets (build & configure `ocserv`, certs, users, NAT). |
| `configure-ocserv.sh` | Writes `/etc/ocserv/ocserv.conf` (auth, port, cert paths, DNS, MTU). |
| `configure-ufw-masquerade.sh` | Adds NAT/masquerade + forwarding rules to UFW. |
| `create-client-services.sh` | Creates systemd services for an always-on client. |

> Server targets live in `Makefile_server`, so they must be run with
> `make -f Makefile_server <target>`. Client targets use the default `Makefile`.

---

## Prerequisites

- Ubuntu/Debian host with `sudo` privileges.
- **Server only:** a public IP and a DNS record (e.g. `vpn.example.com`) pointing to it,
  with TCP port `443` (or your chosen port) reachable so Certbot can issue a certificate.

---

## 1. Clone the repo

```bash
git clone https://github.com/pcDamasceno/vpn.git
cd vpn
sudo apt-get update -y
sudo apt install make -y
```

---

## 2. Configuration variables

All variables can be passed **inline** (`make target VAR=value`) or **exported** as
environment variables (`export VAR=value`) before running `make`.

| Variable | Default | Used by | Meaning |
| --- | --- | --- | --- |
| `EMAIL` | `name@example.com` | server | Email for Let's Encrypt registration. |
| `DOMAIN` | `vpn.example.com` | server/client | FQDN of the VPN server. |
| `TCP_PORT` | `443` | server/client | TCP port `ocserv` listens on / client connects to. |
| `VPN_USER` | `vpnuser` | server/client | VPN account username. |
| `VPN_PASS` | _(none)_ | server | Password used when generating client services. |
| `IFACE` | _(auto-detect)_ | server | Outbound interface for NAT masquerading. |

**Inline example:**

```bash
make -f Makefile_server certbot-standalone EMAIL=you@example.com DOMAIN=vpn.example.com
```

**Environment-variable example:**

```bash
export EMAIL=you@example.com
export DOMAIN=vpn.example.com
export VPN_USER=myuser
make -f Makefile_server certbot-standalone
make -f Makefile_server configure-ocserv
```

---

## 3. Server setup

### 3.1 Base install

Installs dependencies, UFW (allowing SSH), builds `ocserv` from source, installs the
systemd unit, and installs Certbot:

```bash
make -f Makefile_server setup
```

### 3.2 Complete the server workflow

Run these in order after `setup` finishes:

```bash
# 1. Obtain a TLS certificate (standalone challenge — port 80/443 must be free)
make -f Makefile_server certbot-standalone EMAIL=you@example.com DOMAIN=vpn.example.com

# 2. Write /etc/ocserv/ocserv.conf for your domain (and optional port)
make -f Makefile_server configure-ocserv DOMAIN=vpn.example.com

# 3. Enable + start the service
make -f Makefile_server enable-ocserv start-ocserv

# 4. Create a VPN user (you'll be prompted for a password)
make -f Makefile_server create-vpn-user VPN_USER=myuser

# 5. Enable IP forwarding (+ TCP BBR)
make -f Makefile_server enable-ip-forward

# 6. Configure NAT masquerading (auto-detects the interface, or pass IFACE=eth0)
make -f Makefile_server configure-masquerade
```

Check status any time:

```bash
make -f Makefile_server ocserv-status
```

> **Certbot alternatives:** if you already run a web server, use
> `certbot-nginx`, `certbot-apache`, or `certbot-webroot` instead of
> `certbot-standalone`. Test auto-renewal with `make -f Makefile_server certbot-dry-run`.

---

## 4. Client setup

### 4.1 Install the client

```bash
make vpn-setup
```

### 4.2 Connect / disconnect

```bash
# Connect (background). Override any of the values as needed.
make vpn-connect DOMAIN=vpn.example.com TCP_PORT=443 VPN_USER=myuser

# Disconnect
make vpn-disconnect
```

### 4.3 (Optional) Always-on client via systemd

Creates and enables services that auto-reconnect on boot, resume, and connection loss:

```bash
make -f Makefile_server install-oc-client
make -f Makefile_server create-client-services DOMAIN=vpn.example.com VPN_USER=myuser VPN_PASS=secret
make -f Makefile_server start-client-services
```

> The password is stored in the systemd unit for unattended reconnects. Only use this
> on trusted hosts, and restrict access to `/etc/systemd/system/openconnect.service`.

---

## Notes

- The VPN pool is `10.10.10.0/24` and the server gateway is `10.10.10.1`
  (referenced by the client health-check service).
- `configure-ocserv` tunnels all DNS through `8.8.8.8` / `8.8.4.4` and enables
  MTU discovery — edit `configure-ocserv.sh` to change these defaults.
- Ensure your cloud firewall / security group also allows inbound `TCP_PORT`
  in addition to the local UFW rules.
