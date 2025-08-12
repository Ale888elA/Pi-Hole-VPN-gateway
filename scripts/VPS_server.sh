#!/bin/bash
# Script by Ale888elA
# https://github.com/Ale888elA/Pi-Hole-VPN-gateway

set -e

WG_IFACE="wg_cgnat"
WG_PORT="51234"
RPI_VPN_IP="10.100.100.2"
RPI_WG_PORT="51234"

# ===== Software install =====
apt update
apt install -y wireguard iptables-persistent fail2ban

# ===== WireGuard folder creation =====
WG_DIR="/etc/wireguard"
mkdir -p $WG_DIR
cd $WG_DIR

# ===== VPS keys generation =====
umask 077
wg genkey | tee vps_private.key | wg pubkey > vps_public.key

PRIV_KEY=$(cat vps_private.key)
RPI_PUB_KEY="INSERT_RPI_PUBLIC_KEY"

# ===== WireGuard interface configuration =====
cat > $WG_IFACE.conf <<EOF
[Interface]
PrivateKey = $PRIV_KEY
Address = 10.100.100.1/24
ListenPort = $WG_PORT

[Peer]
PublicKey = $RPI_PUB_KEY
AllowedIPs = 10.100.100.2/32
EOF

# ===== Enable IP forwarding =====
sysctl -w net.ipv4.ip_forward=1
grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# ===== Clean IPTABLES current rules =====
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# ===== NAT rules (forward UDP 51234 → RPI) =====
iptables -t nat -A PREROUTING -p udp --dport $WG_PORT -j DNAT --to-destination $RPI_VPN_IP:$RPI_WG_PORT
iptables -t nat -A POSTROUTING -s $RPI_VPN_IP -j MASQUERADE

# ===== Firewall: blocks everything except UDP 50888 and TCP 22 =====
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Loopback
iptables -A INPUT -i lo -j ACCEPT

# Already estabilished connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Logging login tries over UDP 51234 port
# To check logs use:
# journalctl -xe | grep "WG-ATTEMPT"
# or
# grep "WG-ATTEMPT" /var/log/syslog
iptables -A INPUT -p udp --dport $WG_PORT -j LOG --log-prefix "WG-ATTEMPT: " --log-level 4

# WireGuard UDP 51234
iptables -A INPUT -p udp --dport $WG_PORT -j ACCEPT

# SSH TCP 22 (open, but with security key autentication)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Save firewall and NAT rules
netfilter-persistent save

# ===== Fail2ban configuration =====
F2B_JAIL_LOCAL="/etc/fail2ban/jail.local"
cat > "$F2B_JAIL_LOCAL" <<EOF
[DEFAULT]
bantime = 10m
findtime = 10m
maxretry = 3

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = systemd
EOF

# Restart Fail2ban
systemctl enable fail2ban
systemctl restart fail2ban

# ===== Start WireGuard =====
systemctl enable wg-quick@$WG_IFACE
systemctl start wg-quick@$WG_IFACE

# ===== Output VPS public key =====
echo "✅ VPS configured with WireGuard, firewall, logging and Fail2ban."
echo "🔑 VPS public key (to add to VPS_client.sh):"
cat vps_public.key

