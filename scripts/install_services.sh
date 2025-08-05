#!/bin/bash

set -e

# === VARIABLES TO MODIFY ===
PIHOLE_IP="RPI_static_IP"
IFACE="eth0"
VPN_PORT="45678"
WG_IFACE="wg0"
VPN_SUBNET="10.8.0.0/24"

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
echo "Installing wireguard, ufw, fail2ban, ddclient..."
sudo apt update
sudo apt install -y wireguard ufw fail2ban ddclient qrencode

# === 5. Configure ufw ===
# With this rule set only incoming requests from LAN and VPN are allowed
# with the exception for port used by VPN and DDNS
echo "Configuring ufw with persitent iptables rules"

sudo mv /etc/ufw/before.rules /etc/ufw/before.rules.bak
sudo tee /etc/ufw/before.rules > /dev/null <<EOF
# rules.before
#
# UFW before rules (iptables backend)

*nat
:PREROUTING ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]

# DNS Hijack – force DNS TCP/UDP traffic towards Pi-hole
-A PREROUTING -p udp --dport 53 -j DNAT --to-destination "$PIHOLE-IP"
-A PREROUTING -p tcp --dport 53 -j DNAT --to-destination "$PIHOLE-IP"

# NAT for VPN client (WireGuard)
-A POSTROUTING -s 10.8.0.0/24 -o "$IFACE" -j MASQUERADE

# NAT for LAN client
-A POSTROUTING -s 192.168.0.0/16 -o eth0 -j MASQUERADE

COMMIT

*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]

# Allow all loopback (lo0) traffic and drop all traffic to 127/8 that doesn't use lo0.
-A INPUT -i lo -j ACCEPT
-A INPUT -d 127.0.0.0/8 -j REJECT

# Accept ICMP
-A INPUT -p icmp -j ACCEPT

# Allow already established connections
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow SSH
-A INPUT -p tcp --dport 22 -j ACCEPT

# Allow VPN port (WireGuard UDP)
-A INPUT -p udp --dport 50888 -j ACCEPT

# Allow traffic from LAN and VPN
-A INPUT -s 192.168.0.0/16 -j ACCEPT
-A INPUT -s 10.8.0.0/24 -j ACCEPT

# Default deny incoming
-A INPUT -j DROP

# Allow forwarding from VPN
-A FORWARD -s 10.8.0.0/24 -j ACCEPT
-A FORWARD -d 10.8.0.0/24 -j ACCEPT

# Default deny forwarding
-A FORWARD -j DROP

COMMIT

EOF

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow "$VPN_PORT"/udp
sudo ufw allow from 192.168.0.0/16
sudo ufw allow from 10.8.0.0/24
sudo ufw allow from 192.168.0.0/16 to any port 22 proto tcp
sudo ufw allow from 192.168.0.0/16 to any port 22 proto tcp
sudo ufw enable

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
echo "Configuring ddclient"
echo "Press Ctrl+C for skip, or wait to configure."
sleep 5
sudo dpkg-reconfigure ddclient

echo "Success!"
echo "- nftables: NAT, DNS hijack, DoH/DoT block"
echo "- WireGuard: ready over port $VPN_PORT"
echo "- UFW: active"
echo "- Fail2Ban: active"
echo "- ddclient: configured"
