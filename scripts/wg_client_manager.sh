#!/bin/bash
# Script by Ale888elA
# https://github.com/Ale888elA/Pi-Hole-VPN-gateway

############################################
# VARIABLES TO SET
############################################
#
# If your internet connection has a static public IP address and the VPN UDP port
# is forwarded by router settings, set as ENDPOINT your static public IP address;
#
# If your internet connection is NOT under CGNAT,
# if is under NAT2 but your ISP allowed the forward of VPN UDP port
# and if the forwarding of the VPN UDP port is set on your router
# set as endpoint your third level domain obtained from your DDNS service
# (e.g.: mario.myddns.com)
#
# if you have configured a VPN on a VPS that forwards traffic to the the RPI as its client,
# you should set as ENDPOINT the VPS static public IP address or domain;
#
# Otherwise, set as ENDPOINT the static IP address of the RPI
# clients will use VPN connection ONLY when connectet to LAN
#
ENDPOINT="your.thirdlevel.domain"

############################################
# DONT'T CHANGE TO USE DEFAULT VALUES
############################################
# Wireguard VPN network virtual interface
WG_IFACE="wg0"
# Wireguard VPN folder
WG_DIR="/etc/wireguard"
# Wireguard VPN keys folder
KEY_DIR="$WG_DIR/keys"
# Wireguard VPN peer (clients) folder
CLIENT_DIR="$WG_DIR/clients"
# Wireguard VPN subnet
VPN_SUBNET="10.8.0"
# Wireguard VPN UDP port
# Need to be forwarded in your router configuration to access VPN server from WAN 
VPN_PORT="51234"

############################################
# AUTO-DETECTED VARIABLES
############################################
# DNS IP address set to the RPI static IP address;
# DNS queries will be filtered by Pi Hole.
DNS=$(ip -4 addr show $IFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')


[[ $EUID -ne 0 ]] && echo "⚠️ You need root privileges (sudo) to run this script!" && exit 1

mkdir -p "$KEY_DIR" "$CLIENT_DIR"

echo "================================"
echo "    WireGuard Client Manager"
echo "================================"
echo "1 - Create new peer"
echo "2 - Delete existing peer"
read -rp "Select option (1/2): " ACTION

# === DELETE PEER ===
if [[ "$ACTION" == "2" ]]; then
    echo "📋 Configured Peer:"
    grep '\[Peer\]' -A 2 "$WG_DIR/$WG_IFACE.conf" | grep '# ' | sed 's/# //g'
    read -rp "🔻 Name peer to delete: " DELETE_PEER

    sed -i "/# $DELETE_PEER/,+3d" "$WG_DIR/$WG_IFACE.conf"
    rm -f "$KEY_DIR/${DELETE_PEER}_private.key" "$KEY_DIR/${DELETE_PEER}_public.key"
    rm -f "$CLIENT_DIR/${DELETE_PEER}.conf"

    echo "✅ Peer '$DELETE_PEER' deleted."
    exit 0
fi

# === CREATE NEW PEER ===
read -rp "👤 Name new peer (e.g.: smartphone-mario): " PEER_NAME
if grep -q "$PEER_NAME" "$WG_DIR/$WG_IFACE.conf"; then
    echo "❌ Peer already present."
    exit 1
fi

# Keys generation
umask 077
wg genkey | tee "$KEY_DIR/${PEER_NAME}_private.key" | wg pubkey > "$KEY_DIR/${PEER_NAME}_public.key"
PRIV_KEY=$(<"$KEY_DIR/${PEER_NAME}_private.key")
PUB_KEY=$(<"$KEY_DIR/${PEER_NAME}_public.key")
SERVER_PUB_KEY=$(wg show "$WG_IFACE" public-key)

# Look for first free IP address
USED_IPS=$(grep AllowedIPs "$WG_DIR/$WG_IFACE.conf" | grep -oP "$VPN_SUBNET\.\d+")
for i in $(seq 2 254); do
    IP="$VPN_SUBNET.$i"
    if ! echo "$USED_IPS" | grep -q "$IP"; then
        CLIENT_IP="$IP"
        break
    fi
done

[[ -z "$CLIENT_IP" ]] && echo "❌ No IP available on subnet $VPN_SUBNET.0/24" && exit 1

# Add peer to server configuration
echo -e "\n[Peer]  # $PEER_NAME\nPublicKey = $PUB_KEY\nAllowedIPs = $CLIENT_IP/32\nPersistentKeepalive = 25" >> "$WG_DIR/$WG_IFACE.conf"
wg set "$WG_IFACE" peer "$PUB_KEY" allowed-ips "$CLIENT_IP/32" persistent-keepalive 25

# Create client configuration file
CONF_FILE="$CLIENT_DIR/${PEER_NAME}.conf"
cat > "$CONF_FILE" <<EOF
[Interface]
PrivateKey = $PRIV_KEY
Address = $CLIENT_IP/24
DNS = $DNS

[Peer]
PublicKey = $SERVER_PUB_KEY
Endpoint = $ENDPOINT:$VPN_PORT
AllowedIPs = 0.0.0.0/1,128.0.0.0/1
PersistentKeepalive = 25
EOF

echo "✅ Peer added with IP $CLIENT_IP"
echo "📄 Configuration saved in: $CONF_FILE"

# QR code
if command -v qrencode >/dev/null; then
    echo "📱 QR Code:"
    qrencode -t ansiutf8 < "$CONF_FILE"
else
    echo "ℹ️  Install 'qrencode' to generate QR Code (sudo apt install -y qrencode)"
fi

