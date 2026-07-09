.PHONY: update upgrade install-deps install-ufw ufw-enable ufw-allow-ssh ufw-status install-git setup \
	install-oc-client vpn-connect vpn-status vpn-disconnect

PID_FILE ?= /run/openconnect.pid

update:
	sudo apt update

upgrade:
	sudo apt upgrade -y

install-deps:
	sudo apt install wget curl nano software-properties-common dirmngr apt-transport-https gnupg2 ca-certificates lsb-release unzip -y

install-ufw:
	sudo apt install ufw -y

ufw-allow-ssh:
	sudo ufw allow 22/tcp

ufw-enable:
	echo "y" | sudo ufw enable

ufw-status:
	sudo ufw status

install-git:
	sudo apt install git -y

# --- OpenConnect VPN Client ---

install-oc-client:
	sudo apt install openconnect -y

vpn-connect:
	sudo openconnect -b --pid-file=$(PID_FILE) $(DOMAIN):$(TCP_PORT) -u $(VPN_USER)

# Exits 0 when the tunnel is up, 1 when it is down, so it can gate other targets.
vpn-status:
	@pid=$$(cat $(PID_FILE) 2>/dev/null); \
	if [ -z "$$pid" ] || [ "$$(cat /proc/$$pid/comm 2>/dev/null)" != openconnect ]; then \
		pid=$$(pgrep -x openconnect | head -n1); \
	fi; \
	if [ -z "$$pid" ]; then \
		echo "==> VPN is DOWN (no openconnect process)"; \
		exit 1; \
	fi; \
	echo "==> VPN is UP (openconnect pid $$pid)"; \
	ip -br addr show type tun 2>/dev/null | sed 's/^/    /'; \
	ip route show dev $$(ip -br link show type tun | awk 'NR==1{print $$1}') 2>/dev/null | sed 's/^/    route: /'

vpn-disconnect:
	@pid=$$(cat $(PID_FILE) 2>/dev/null); \
	if [ -z "$$pid" ] || [ "$$(cat /proc/$$pid/comm 2>/dev/null)" != openconnect ]; then \
		pid=$$(pgrep -x openconnect | head -n1); \
	fi; \
	if [ -z "$$pid" ]; then \
		echo "==> No openconnect process found"; \
		sudo rm -f $(PID_FILE); \
		exit 0; \
	fi; \
	echo "==> Logging off session and disconnecting (pid $$pid)..."; \
	sudo kill -INT "$$pid"; \
	for i in $$(seq 1 10); do [ -d /proc/$$pid ] || break; sleep 1; done; \
	if [ -d /proc/$$pid ]; then \
		echo "==> Clean shutdown timed out after 10s, forcing SIGKILL (routes may need manual cleanup)"; \
		sudo kill -9 "$$pid"; sleep 1; \
	fi; \
	sudo rm -f $(PID_FILE); \
	echo "==> VPN disconnected"

# --- Full Setup ---

vpn-setup: update upgrade install-deps install-ufw ufw-allow-ssh ufw-enable install-git install-oc-client
	@echo "==> Setup complete."
	@echo "==> Connect to VPN:"
	@echo "  make vpn-connect"
	@echo "  make vpn-connect DOMAIN=host TCP_PORT=port VPN_USER=user"
	@echo "==> Check status:"
	@echo "  make vpn-status"
	@echo "==> Disconnect:"
	@echo "  make vpn-disconnect"
