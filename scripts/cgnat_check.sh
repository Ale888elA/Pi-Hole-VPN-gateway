#!/bin/bash

# Needs root privileges
[[ $EUID -ne 0 ]] && echo "⚠️ You need root privileges (sudo) to run this script" && exit 1

IP_PUB=$(curl -s https://ifconfig.me)
IP_LOC=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -vE '^127\.|^169\.254\.')
IP_WAN=$(ip route get 1.1.1.1 | grep -oP 'src \K[\d.]+')

echo "=================================================="
echo "            🌐 Check CGNAT Active"
echo "=================================================="
echo -e "\n🌐 Public IP (visible online): $IP_PUB"
echo "🏠 Local IP (Raspberry):         $IP_LOC"
echo "🔌 WAN IP (from router):         $IP_WAN"

# Check if public IP matches WAN IP
if [[ "$IP_PUB" != "$IP_WAN" ]]; then
    echo -e "\n❗ Your public IP is different from WAN IP → CGNAT possible"
else
    echo -e "\n✅ Your public IP match with WAN IP → Probably you are NOT under CGNAT"
fi

# Check if WAN IP is in CGNAT range or private
check_range() {
    IP="$1"
    if [[ $IP =~ ^192\.168\. ]] || [[ $IP =~ ^10\. ]] || [[ $IP =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
        echo "🔒 WAN IP is in a LAN private range → Probably NAT2"
    elif [[ $IP =~ ^100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\. ]]; then
        echo "🔒 WAN IP is in CGNAT range (100.64.0.0/10) → CGNAT ACTIVE"
    fi
}
check_range "$IP_WAN"

echo -e "\n✅ Check complete."

