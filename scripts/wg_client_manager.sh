#!/bin/bash

WG_INTERFACE="wg0"
WG_DIR="/etc/wireguard"
KEY_DIR="$WG_DIR/keys"
CLIENT_DIR="$WG_DIR/clients"
# Set as endpoint your third level domain obtained from your DDNS service
# works only if you're not under CGNAT and the VPN port forwarding
# on your router and on your line if you're under NAT2 has been set properly
# If you plan to use your client only when connected to LAN comment with # line below
ENDPOINT="your.thirdlevel.domain"
# If you commented ENDPOINT line before this one and
# you plan to use your client only when connected to LAN 
# set your RPI static IP address between quotes in line below this one and uncomment it
#ENDPOINT="192.168.XXX.XXX"
SERVER_PORT="51234"
VPN_SUBNET="10.8.0"

[[ $EUID -ne 0 ]] && echo "⚠️ You need root privileges (sudo) to run this script" && exit 1

mkdir -p "$KEY_DIR" "$CLIENT_DIR"

echo "================================"
echo "    WireGuard Client Manager"
echo "================================"
echo "1 - Crea nuovo peer"
echo "2 - Elimina peer esistente"
read -rp "Seleziona un'opzione (1/2): " ACTION

# === ELIMINA PEER ===
if [[ "$ACTION" == "2" ]]; then
    echo "📋 Peer configurati:"
    grep '\[Peer\]' -A 2 "$WG_DIR/$WG_INTERFACE.conf" | grep '# ' | sed 's/# //g'
    read -rp "🔻 Nome peer da eliminare: " DELETE_PEER

    sed -i "/# $DELETE_PEER/,+3d" "$WG_DIR/$WG_INTERFACE.conf"
    rm -f "$KEY_DIR/${DELETE_PEER}_private.key" "$KEY_DIR/${DELETE_PEER}_public.key"
    rm -f "$CLIENT_DIR/${DELETE_PEER}.conf"

    echo "✅ Peer '$DELETE_PEER' eliminato."
    exit 0
fi

# === CREA NUOVO PEER ===
read -rp "👤 Nome nuovo peer (es. smartphone-mario): " PEER_NAME
if grep -q "$PEER_NAME" "$WG_DIR/$WG_INTERFACE.conf"; then
    echo "❌ Peer già esistente."
    exit 1
fi

# Genera chiavi
umask 077
wg genkey | tee "$KEY_DIR/${PEER_NAME}_private.key" | wg pubkey > "$KEY_DIR/${PEER_NAME}_public.key"
PRIV_KEY=$(<"$KEY_DIR/${PEER_NAME}_private.key")
PUB_KEY=$(<"$KEY_DIR/${PEER_NAME}_public.key")
SERVER_PUB_KEY=$(wg show "$WG_INTERFACE" public-key)

# Calcola primo IP libero
USED_IPS=$(grep AllowedIPs "$WG_DIR/$WG_INTERFACE.conf" | grep -oP "$VPN_SUBNET\.\d+")
for i in $(seq 2 254); do
    IP="$VPN_SUBNET.$i"
    if ! echo "$USED_IPS" | grep -q "$IP"; then
        CLIENT_IP="$IP"
        break
    fi
done

[[ -z "$CLIENT_IP" ]] && echo "❌ Nessun IP disponibile nella subnet $VPN_SUBNET.0/24" && exit 1

# Aggiungi peer alla configurazione server
echo -e "\n[Peer]  # $PEER_NAME\nPublicKey = $PUB_KEY\nAllowedIPs = $CLIENT_IP/32\nPersistentKeepalive = 25" >> "$WG_DIR/$WG_INTERFACE.conf"
wg set "$WG_INTERFACE" peer "$PUB_KEY" allowed-ips "$CLIENT_IP/32" persistent-keepalive 25

# Crea file configurazione client
CONF_FILE="$CLIENT_DIR/${PEER_NAME}.conf"
cat > "$CONF_FILE" <<EOF
[Interface]
PrivateKey = $PRIV_KEY
Address = $CLIENT_IP/24
DNS = 192.168.71.252

[Peer]
PublicKey = $SERVER_PUB_KEY
Endpoint = $ENDPOINT:$SERVER_PORT
AllowedIPs = 0.0.0.0/1,128.0.0.0/1
PersistentKeepalive = 25
EOF

echo "✅ Peer aggiunto con IP $CLIENT_IP"
echo "📄 Configurazione salvata in: $CONF_FILE"

# QR opzionale
if command -v qrencode >/dev/null; then
    echo "📱 QR Code:"
    qrencode -t ansiutf8 < "$CONF_FILE"
else
    echo "ℹ️  Installa 'qrencode' per generare QR Code (sudo apt install qrencode)"
fi

