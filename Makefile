.PHONY: update upgrade install-deps install-ufw ufw-enable ufw-allow-ssh ufw-status install-git setup \
	install-oc-client vpn-connect vpn-disconnect

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
	sudo openconnect -b $(DOMAIN):$(TCP_PORT) -u $(VPN_USER)

vpn-disconnect:
	sudo pkill openconnect || echo "==> No openconnect process found"

# --- Full Setup ---

vpn-setup: update upgrade install-deps install-ufw ufw-allow-ssh ufw-enable install-git install-oc-client
	@echo "==> Setup complete."
	@echo "==> Connect to VPN:"
	@echo "  make vpn-connect"
	@echo "  make vpn-connect DOMAIN=host TCP_PORT=port VPN_USER=user"
	@echo "==> Disconnect:"
	@echo "  make vpn-disconnect"
