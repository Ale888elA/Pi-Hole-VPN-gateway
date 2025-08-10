#!/bin/bash
# Script by Ale888elA
# https://github.com/Ale888elA/Pi-Hole-VPN-gateway

set -e

############################################
# VARIABLES TO SET
############################################

# DONT'T CHANGE TO USE DEFAULT VALUES

# Wireguard VPN UDP port
# Need to be forwarded in your router configuration to access VPN server from WAN 
VPN_PORT="51234"

# Wireguard VPN network virtual interface
WG_IFACE="wg0"

# Wireguard VPN subnet
VPN_SUBNET="10.8.0.0/24"

# This values will be autodetected
# RPI_IP="RPI_static_IP"
# IFACE="eth0"

############################################
# AUTO-DETECTED VARIABLES
############################################

# Raspberry Pi active network interface
IFACE=$(ip -o -4 addr show up primary scope global | awk '{print $2; exit}')

# Raspberry Pi static IP address (RPI_static_IP)
RPI_IP=$(ip -4 addr show $IFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

echo "Starting setup Raspberry Pi as gateway/VPN with safe nftables"

# === 1. Disable IPv6 ===
echo "Disabling IPv6..."
cat <<EOF | sudo tee /etc/sysctl.d/99-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sudo sysctl -p /etc/sysctl.d/99-disable-ipv6.conf

# === 2. Enable IP forwarding ===
echo "Enabling IP forwarding..."
sudo sed -i '/^#net.ipv4.ip_forward=1/c\net.ipv4.ip_forward=1' /etc/sysctl.conf
sudo sysctl -w net.ipv4.ip_forward=1

# === 3. Install software packages ===
echo "Installing wireguard, nftables, fail2ban, ddclient..."
sudo apt update
sudo apt install -y wireguard nftables fail2ban ddclient qrencode

# === 5. Configure nftables ===
# With this rule set only incoming requests from LAN and VPN are allowed
# with the exception for port used by VPN and DDNS
# Also SSH port will be reachable only from LAN/VPN.
echo "Creating persistent nftables configuration..."

NFT_CONF="/etc/nftables.conf"

sudo tee "$NFT_CONF" > /dev/null <<EOF
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0;
        policy drop;

        iif "lo" accept
        ct state established,related accept

        # LAN and VPN - full access
        ip saddr 192.168.0.0/16 accept
        ip saddr 10.8.0.0/24 accept

        # WireGuard port (VPN access)
        udp dport $VPN_PORT accept

        # SSH access only from LAN and VPN
        ip saddr { 192.168.0.0/16, 10.8.0.0/24 } tcp dport 22 accept
        tcp dport 22 drop

        # Log and final drop
        log prefix "nftables input drop: " flags all counter
        drop
    }

    chain forward {
        type filter hook forward priority 0;
        policy drop;

        ct state established,related accept
        ip saddr 10.8.0.0/24 accept
        ip daddr 10.8.0.0/24 accept
        ip saddr 192.168.0.0/16 oifname "$IFACE" accept
    }

    chain output {
        type filter hook output priority 0;
        policy accept;

        # Block DNS-over-TLS
        tcp dport 853 drop

        # Block DNS-over-HTTPS
        ip daddr { 1.1.1.1, 1.0.0.1, 8.8.8.8, 8.8.4.4, 9.9.9.9 } tcp dport 443 drop
        ip6 daddr { 2606:4700:4700::1111, 2001:4860:4860::8888 } tcp dport 443 drop
    }
}

table ip nat {
    chain prerouting {
        type nat hook prerouting priority 0;

        # DNS hijack toward Pi-hole
        tcp dport 53 dnat to $RPI_IP
        udp dport 53 dnat to $RPI_IP
    }

    chain postrouting {
        type nat hook postrouting priority 100;

        ip saddr 10.8.0.0/24 oifname "$IFACE" masquerade
        ip saddr 192.168.0.0/16 oifname "$IFACE" masquerade
    }
}
EOF


sudo systemctl enable nftables
sudo systemctl start nftables

# === 6. Configure Wireguard server ===
echo "Configuring WireGuard server..."
WG_DIR="/etc/wireguard"
sudo mkdir -p "$WG_DIR"
cd "$WG_DIR"

if [[ ! -f server.key ]]; then
    umask 077
    wg genkey | tee server.key | wg pubkey > server.pub
fi

PRIVATE_KEY=$(cat server.key)

cat <<EOF | sudo tee "$WG_DIR/$WG_IFACE.conf" > /dev/null
[Interface]
PrivateKey = $PRIVATE_KEY
Address = 10.8.0.1/24
ListenPort = $VPN_PORT
EOF

sudo systemctl enable "wg-quick@$WG_IFACE"
sudo systemctl start "wg-quick@$WG_IFACE"

# === 7. Configure fail2ban ===
echo "Configuring Fail2Ban..."
cat <<EOF | sudo tee /etc/fail2ban/jail.d/ssh.conf
[sshd]
enabled = true
port = ssh
filter = sshd
backend = systemd
maxretry = 5
EOF

sudo systemctl restart fail2ban

# === 8. Configure ddclient ===
# If your internet connection has a static IP address you can cmment next four script lines
# and last line, with # symbol at beginning of the lines;
# you can also uninstall ddclient: sudo apt --purge remove -y ddclient
echo "Configuring ddclient"
echo "Press Ctrl+C for skip, or wait to configure."
sleep 10
sudo dpkg-reconfigure ddclient

echo "Success!"
echo "- IPv6 traffic blocked"
echo "- IP forwarding enabled"
echo "- nftables: NAT, DNS hijack, DoH/DoT and firewall rules applied"
echo "- WireGuard: ready over port $VPN_PORT"
echo "- Fail2Ban: active"
echo "- ddclient: configured"

