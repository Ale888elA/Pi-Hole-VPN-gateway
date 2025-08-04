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
echo "Installing nftables, wireguard, ufw, fail2ban, ddclient..."
sudo apt update
sudo apt install -y nftables wireguard ufw fail2ban ddclient qrencode

# === 4. Configure persistent nftables ===
echo "Creating persistent nftables configuration..."

NFT_CONF="/etc/nftables.conf"

sudo tee "$NFT_CONF" > /dev/null <<EOF
!/usr/sbin/nft -f

flush ruleset

##############################################
# TABLE: NAT
##############################################

table ip nat {
    chain prerouting {
        type nat hook prerouting priority 0;

        # DNS Hijacking - redirects all DNS traffic toward your local DNS
        tcp dport 53 dnat to "$PIHOLE_IP"
        udp dport 53 dnat to "$PIHOLE_IP"
    }

    chain postrouting {
        type nat hook postrouting priority 100;

        # NAT for VPN outbound traffic over your connecting device
        oifname ""$IFACE"" masquerade
    }
}


##############################################
# TABLE: FILTER
##############################################

table inet filter {
    chain input {
        type filter hook input priority 0;
        policy accept;
    }

    chain forward {
        type filter hook forward priority 0;
        policy accept;
    }

    chain output {
        type filter hook output priority 0;
        policy accept;

        # Blocks DNS-over-TLS (853 TCP port)
        tcp dport 853 drop

        # Blocks DNS-over-HTTPS (DoH)
        ip daddr { 1.1.1.1, 1.0.0.1, 8.8.8.8, 8.8.4.4, 9.9.9.9 } tcp dport 443 drop
        ip6 daddr { 2606:4700:4700::1111, 2001:4860:4860::8888 } tcp dport 443 drop
    }
}

EOF

sudo systemctl enable nftables
sudo systemctl restart nftables

# === 5. Configure ufw ===
# With this rule set only incoming requests from LAN and VPN are allowed
# with the exception for port used by VPN and DDNS
echo "Configuring ufw..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow "$VPN_PORT"/udp
sudo ufw allow from 192.168.0.0/16
sudo ufw allow from 10.8.0.0/24
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
logpath = /var/log/auth.log
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
