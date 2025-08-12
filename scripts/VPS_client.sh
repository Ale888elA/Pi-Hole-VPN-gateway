#!/bin/bash
# Script by Ale888elA
# https://github.com/Ale888elA/Pi-Hole-VPN-gateway

WG_IFACE="wg_cgnat"
WG_DIR="/etc/wireguard"
VPS_IP="1.2.3.4"             # VPS server static public IP
WG_PORT="51234"
RPI_IP="10.100.100.2"
VPS_IP_VPN="10.100.100.1"

# Check that wireguard is installed
apt update && apt install -y wireguard

# Generate keys
mkdir -p $WG_DIR
cd $WG_DIR

umask 077
wg genkey | tee rpi_private.key | wg pubkey > rpi_public.key

PRIV_KEY=$(cat rpi_private.key)
VPS_PUB_KEY="INSERT_VPS_PUBLIC_KEY"  # After VPS server key generation

cat > $WG_IFACE.conf <<EOF
[Interface]
PrivateKey = $PRIV_KEY
Address = $RPI_IP/24

[Peer]
PublicKey = $VPS_PUB_KEY
AllowedIPs = 0.0.0.0/0
Endpoint = $VPS_IP:$WG_PORT
PersistentKeepalive = 25
EOF

# Enable forwarding
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Eanble and start WireGuard
systemctl enable wg-quick@$WG_IFACE
systemctl start wg-quick@$WG_IFACE

echo "✅ Raspberry configured as WireGuard client of VPS server."
echo "🔑 Raspberry public key to add to server config file:"
cat rpi_public.key
