# Using-a-Raspberry-Pi-as-a-VPN-server-Gateway-DNS-sinkhole
MAIN GOALS:
    • install and configure on the Raspberry PI (RPI) a Virtual Private Network (VPN) server using Wireguard protocol;
    • install and configure on the RPI a network-wide DNS sinkhole for blocking ads, tracking, scam, malware and phishing known referrals using Pi Hole;
    • configure the RPI to be used as gateway, to block IPv6 traffic for security purposes and hijack hard-coded DNS providers on Smart-TVs.

SECONDARY GOALS:
    • configure the RPI to refuse SSH password access and use a security token instead;
    • prevent SSH brute-force attacks on SSH port using failtoban;
    • setup NAT and firewall rules for security purposes;
    • configure a Dynamic DNS Service (DYNDNS) to access the VPN server through the dynamic public IP address given by your Internet Service Provider (ISP) from smartphones and laptops while are not connected to the Local Area Network (LAN);
    • configure unattended-upgrades to automate Raspberry Pi OS updates;
    • implement a watchdog service that regularly checks the VPN server status;
    • automate the upload of a compressed and password protected backup of RPI configuration on Google Drive or other cloud storage services;
    • implement a script to automate the creation of new VPN clients assigning an unused VPN IP address and creating a QR configuration code for smartphones;
    • implement a script to automate the purge of all VPN created clients and their keys;
    • implement a daemon service that flushes NAT rules on RPI boot;
    • implement a script for manual diagnosis of the RPI;
    • implement a script for manual restore from a backup compressed file.

The hardware used is a RPI 4 4Gb RAM with a 64Gb microSD memory card, cable connected to my 5G modem/router LAN port, but it can be set to use Wi-Fi connection instead. It will also works on RPI 3 models.
The operative system installed on the RPI is Raspberry Pi OS 64bit headless (without desktop environment), based on Linux Debian Bookworm.
Required additional Linux software packages from APT: unattended-upgrades, bsd-mailx, nftables, ufw, fail2ban, wireguard, qrencode, rclone, ddclient, zip, unzip.
Required additional Linux software: Pi-Hole (GitHub).
PC used for programming the RPI client-side uses Arch Linux.
