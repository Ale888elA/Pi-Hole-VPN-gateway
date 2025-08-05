#!/bin/bash

# Set static IP address of Raspberry Pi
RPI_IP="RPI_static_IP"
# Set interface in use: eth0 or wlan0
IFACE="eth0"
# Set udp port used by VPN and DDNS
VPN_PORT="45678"

echo "=============================="
echo "     Services diagnosis       "
echo "=============================="

# 1. WireGuard
echo -e "\n[1] WireGuard service status:"
systemctl is-active wg-quick@wg0 &>/dev/null && echo "✅ Active" || echo "❌ Inactive"

echo -e "\n[10] Check UDP "$VPN_PORT" port (WireGuard/DDNS):"

# Check if the port is listenig locally
if sudo ss -uln | grep -q ":"$VPN_PORT""; then
    echo "✅ UDP "$VPN_PORT" port is listening locally"
else
    echo "❌ UDP "$VPN_PORT" port is NOT listening locally"
fi

# Check if is allowed by firewall (nftables)
if sudo nft list chain inet filter input | grep -q 'udp dport "$VPN_PORT" accept'; then
    echo "✅ UDP "$VPN_PORT" port is allowed by firewall"
else
    echo "⚠️  No firewall rule for UDP "$VPN_PORT" port find"
fi

# 2. IP forwarding
echo -e "\n[2] IP forwarding:"
[[ $(sysctl -n net.ipv4.ip_forward) == "1" ]] && echo "✅ Active" || echo "❌ Disabled"

# 3. nftables service status
echo -e "\n[1] nftables service status:"
systemctl is-active nftables &>/dev/null && echo "✅ Active" || echo "❌ Inactive"

# 4. Masquerade over "$IFACE"
echo -e "\n[2] Regola MASQUERADE su "$IFACE":"
if sudo nft list chain ip nat postrouting | grep -q 'masquerade'; then
    echo "✅ Present"
else
    echo "❌ Missing"
fi

# 5. DNS Hijack TCP/UDP port 53
echo -e "\n[3] DNS Hijack TCP/UDP (porta 53 → "$RPI_IP"):"
TCP_RULE=$(sudo nft list chain ip nat prerouting | grep 'tcp dport 53' | grep 'dnat to "$RPI_IP"')
UDP_RULE=$(sudo nft list chain ip nat prerouting | grep 'udp dport 53' | grep 'dnat to "$RPI_IP"')

if [[ -n "$TCP_RULE" && -n "$UDP_RULE" ]]; then
    echo "✅ TCP/UDP rules present"
else
    echo "❌ Rules missing"
fi

# 6. SSH filter from LAN/VPN
echo -e "\n[4] SSH access restricted from LAN/VPN:"
SSH_RULE=$(sudo nft list chain inet filter input | grep 'tcp dport 22' | grep -E '192\.168\.|10\.8\.')

if [[ -n "$SSH_RULE" ]]; then
    echo "✅ SSH rule present"
else
    echo "⚠️  No SSH limit rule find"
fi

# 7. Chains
echo -e "\n[5] Chains:"
sudo nft list ruleset | grep -q 'table ip nat' && echo "✅ NAT" || echo "❌ NAT missing"
sudo nft list ruleset | grep -q 'table inet filter' && echo "✅ FILTER" || echo "❌ FILTER missing"

# 8. Show interfaces
echo -e "\n[6] Active interfaces:"
ip -brief addr | grep UP

# 9. Active VPN clients
echo -e "\n[5] Active Peers:"
wg show | awk '/peer:/{print "\n🔹 Peer: " $2} /allowed ips:|endpoint:|latest handshake:|transfer:/{print "   " $0}'

# 10. DNS test
echo -e "\n[6] DNS test:"
host google.com 1.1.1.1 &>/dev/null && echo "✅ DNS working" || echo "❌ DNS NOT working"

# 11. Pi-hole Web Interface
echo -e "\n[7] Pi-hole Web:"
curl -s --connect-timeout 2 http://127.0.0.1/admin/ > /dev/null && echo "✅ Web active" || echo "❌ NOT reachable"

# 12. Outbound ping test
echo -e "\n[8] Ping to 8.8.8.8:"
ping -c 1 -W 2 8.8.8.8 &>/dev/null && echo "✅ Internet OK" || echo "❌ NO outbound access"

# 13. Fail2Ban
echo -e "\n[10] Fail2Ban:"
systemctl is-active fail2ban &>/dev/null && echo "✅ Active" || echo "❌ Inactive"

echo -e "\n✅ Diagnosis completed."

