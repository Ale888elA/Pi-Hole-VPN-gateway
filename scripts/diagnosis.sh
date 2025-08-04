#!/bin/bash

# set active network interface: eth0 for cable connected or wlan0 for Wi-Di connection.
IFACE="eth0"
# set Raspberry Pi static IP address.
RPI_IP="192.168.xxx.xxx"

echo "=============================="
echo " WireGuard VPN Diagnostic Tool"
echo "=============================="

# 1. WireGuard status
echo -e "\n[1] WireGuard service status:"
systemctl is-active wg-quick@wg0 && echo "✅ Active" || echo "❌ NOT active"

# 2. IP forwarding
echo -e "\n[2] IP forwarding:"
IPFWD=$(sysctl -n net.ipv4.ip_forward)
[[ "$IPFWD" -eq 1 ]] && echo "✅ Active" || echo "❌ NOT active"

# 3. Regola masquerade su eth0
echo -e "\n[3] Masquerade rule on "$IFACE" in nftables:"
nft list ruleset | grep -q 'oifname ""$IFACE"" masquerade' && echo "✅ Present" || echo "❌ Missing"

# 4. DNS hijack
echo -e "\n[4] DNS hijack active (port 53 to "$RPI_IP"):"
nft list ruleset | grep -q 'dnat to "$RPI_IP"' && echo "✅ Rules present" || echo "⚠️ DNS hijack missing"

# 5. Connected Peers
echo -e "\n[5] Active VPN clients:"
ACTIVE_PEERS=$(wg show wg0 endpoints 2>/dev/null | wc -l)
if [[ "$ACTIVE_PEERS" -eq 0 ]]; then
    echo "⚠️  No active peer"
else
    wg show wg0 | awk '/peer:/{print "\n👤 Peer: " $2} /allowed ips|endpoint|transfer|latest/ {print "   " $0}'
fi

# 6. DNS test from server
echo -e "\n[6] DNS resolutin test (google.com):"
RES=$(dig +short google.com @"$RPI_IP" | head -n 1)
if [[ -z "$RES" ]]; then
    echo "❌ No reply from "$RPI_IP""
else
    echo "✅ DNS working: google.com → $RES"
fi

# 7. Pi-hole status (web Port check)
echo -e "\n[7] Pi-hole status:"
if nc -z 127.0.0.1 80; then
    echo "✅ Pi-hole web interfce active (port 80)"
else
    echo "⚠️  Pi-hole not reachable on port 80"
fi

# 8. Ping Google from server
echo -e "\n[8] Internet connection test (ping 8.8.8.8):"
ping -c 2 -W 2 8.8.8.8 &>/dev/null && echo "✅ Internet reachable" || echo "❌ Internet NOT reachable"

# 9. Active interfaces
echo -e "\n[9] Active NET interfaces:"
ip -br addr show | grep UP

# 10. UFW status
echo -e "\n[UFW - Firewall]"
if command -v ufw >/dev/null; then
    sudo ufw status verbose
else
    echo "⚠️  UFW NOT installed"
fi

# 11. Fail2Ban status
echo -e "\n[Fail2Ban]"
if systemctl list-unit-files | grep -q fail2ban; then
    systemctl is-active --quiet fail2ban && echo "✅ Active" || echo "❌ NOT active"
    echo "📋 Jail attive:"
    sudo fail2ban-client status | grep 'Jail list' || echo "⚠️  No active jail or fail2ban not properly configured"
else
    echo "⚠️  Fail2Ban NOT installed"
fi

echo -e "\n✅ Diagnosis completed."

