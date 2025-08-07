#!/bin/bash

# Set static IP address of Raspberry Pi
RPI_IP="RPI_static_IP"
# Set interface in use: eth0 or wlan0
IFACE="eth0"
# Set udp port used by VPN and DDNS
VPN_PORT="51234"

echo "=============================="
echo "= 🔍  Services diagnosis     ="
echo "=============================="

# 1. Show active interfaces
echo -e "\n[1] Active interfaces:"
echo "NAME           STATUS              IP ADDRESS"
ip -brief addr | grep UP

# 2. IP forwarding
echo -e "\n[2] IP forwarding:"
[[ $(sysctl -n net.ipv4.ip_forward) == "1" ]] && echo "✅ Active" || echo "❌ NOT active"

# 3. NFTABLES service status
echo -e "\n[3] NFTABLES service status:"
systemctl is-active nftables &>/dev/null && echo "✅ Active" || echo "❌ NOT active"

# 4. Presence of expected rooting chains
echo -e "\n[4] Rooting chains:"
sudo nft list ruleset | grep -q 'table ip nat' && echo "✅ NAT" || echo "❌ NAT missing"
sudo nft list ruleset | grep -q 'table inet filter' && echo "✅ FILTER" || echo "❌ FILTER missing"

# 5. LAN routing
echo -e "\n[5] LAN traffic routing (192.168.0.0/16) enabled:"
if sudo nft list chain inet filter forward | grep -q 'ip saddr 192.168.0.0/16'; then
    echo "✅ LAN routing enabled"
else
    echo "❌ Rule missing: LAN traffic blocked (LAN clients will not have internet access)"
fi

# 6. VPN routing
echo -e "\n[6] VPN traffic routing (10.8.0.0/24) enabled:"
if sudo nft list chain inet filter forward | grep -q 'ip saddr 10.8.0.0/24'; then
    echo "✅ VPN routing enabled"
else
    echo "❌ Rule missing: VPN traffic blocked (VPN clients will not have internet access)"
fi

# 7. DNS Hijack TCP/UDP port 53
echo -e "\n[7] DNS Hijack TCP/UDP (port 53 → $RPI_IP):"
TCP_RULE=$(sudo nft list chain ip nat prerouting | grep 'tcp dport 53' | grep "dnat to $RPI_IP")
UDP_RULE=$(sudo nft list chain ip nat prerouting | grep 'udp dport 53' | grep "dnat to $RPI_IP")

if [[ -n "$TCP_RULE" && -n "$UDP_RULE" ]]; then
    echo "✅ Rules TCP/UDP present"
else
    echo "❌ Rules missing"
fi

# 8. SSH filtering rule from LAN/VPN
echo -e "\n[8] SSH access only from LAN/VPN:"
SSH_RULE=$(sudo nft list chain inet filter input | grep 'tcp dport 22' | grep -E '192\.168\.|10\.8\.')

if [[ -n "$SSH_RULE" ]]; then
    echo "✅ SSH rule present"
else
    echo "⚠️ No SSH filtering rule found"
fi

# 9. MASQUERADE
echo -e "\n[9] MASQUERADE rules on $IFACE:"

VPN_RULE_OK=$(sudo nft list chain ip nat postrouting | grep -q 'ip saddr 10.8.0.0/24 .* masquerade' && echo "ok")
LAN_RULE_OK=$(sudo nft list chain ip nat postrouting | grep -q 'ip saddr 192.168.0.0/16 .* masquerade' && echo "ok")

if [[ "$VPN_RULE_OK" == "ok" ]]; then
    echo "✅ VPN (10.8.0.0/24) → MASQUERADE on $IFACE: present"
else
    echo "❌ VPN (10.8.0.0/24) → MASQUERADE on $IFACE: missing"
fi

if [[ "$LAN_RULE_OK" == "ok" ]]; then
    echo "✅ LAN (192.168.0.0/16) → MASQUERADE on $IFACE: present"
else
    echo "❌ LAN (192.168.0.0/16) → MASQUERADE on $IFACE: missing"
fi

# 10. WIREGUARD
echo -e "\n[10] WIREGUARD service status:"
systemctl is-active wg-quick@wg0 &>/dev/null && echo "✅ Active" || echo "❌ NOT active"

# 11. Wireguard/DDNS udp port check
echo -e "\n[11] Check UDP $VPN_PORT port (WireGuard/DDNS):"

# Check if port is listenig locally
if sudo ss -uln | grep -q ":$VPN_PORT"; then
    echo "✅ UDP $VPN_PORT port is listening locally"
else
    echo "❌ UDP $VPN_PORT port is NOT listening locally"
fi

# Check if port is allowed by firewall rules (nftables)
if sudo nft list chain inet filter input | grep -q "udp dport $VPN_PORT accept"; then
    echo "✅ UDP $VPN_PORT port is allowed by firewall"
else
    echo "⚠️ No firewall rule for UDP $VPN_PORT port find"
fi

# 12. Active VPN clients
echo -e "\n[12] Active Wireguard peers:"
wg show | awk '/peer:/{print "\n🔹 Peer: " $2} /allowed ips:|endpoint:|latest handshake:|transfer:/{print "   " $0}'

# 13. DNS test
echo -e "\n[13] DNS test:"
host google.com 1.1.1.1 &>/dev/null && echo "✅ DNS working" || echo "❌ DNS NOT working"

# 14. PI HOLE Web Interface
echo -e "\n[14] PI HOLE Web:"
curl -s --connect-timeout 2 http://127.0.0.1/admin/ > /dev/null && echo "✅ Web active" || echo "❌ NOT reachable"

# 15. Outbound ping test
echo -e "\n[15] Ping to 8.8.8.8:"
ping -c 1 -W 2 8.8.8.8 &>/dev/null && echo "✅ Internet OK" || echo "❌ NO outbound access"

# 16. FAIL2BAN
echo -e "\n[16] FAIL2BAN:"
systemctl is-active fail2ban &>/dev/null && echo "✅ Active" || echo "❌ NOT active"

echo -e "\n✅ Diagnosis completed."

