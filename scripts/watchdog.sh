#!/bin/bash

WG_INTERFACE="wg0"
DNS_CHECK="pi.hole"

# Check WireGuard handshake
if ! sudo wg show $WG_INTERFACE | grep -q "latest handshake"; then
    echo "WireGuard inactive. Restart..."
    systemctl restart wg-quick@$WG_INTERFACE
fi

# Check Pi-hole DNS
if ! dig @$DNS_CHECK | grep -q "ANSWER SECTION"; then
    echo "Pi-hole is non respondig. Restart DNS and Pi-hole..."
    systemctl restart pihole-FTL
fi
