apt-get update -y
apt install make -y

make -f Makefile_server setup

**Workflow after `make -f Makefile_server setup` completes:**
```bash
make -f Makefile_server certbot-standalone EMAIL=you@example.com DOMAIN=vpn.example.com
make -f Makefile_server configure-ocserv DOMAIN=vpn.example.com
make -f Makefile_server enable-ocserv start-ocserv
make -f Makefile_server create-vpn-user VPN_USER=myuser
make -f Makefile_server enable-ip-forward
make -f Makefile_server configure-masquerade
```