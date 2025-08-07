## Using a Raspberry Pi as a VPN server, Gateway and DNS sinkhole
This guide is suited for the security exigences of a home network and for private use; in a business environment, especially if you deal with customer’s sensible data, is strongly advised to use a professional device that uses pfsense firewall software and strong VPN encryption; <a href="https://www.netgate.com/" target="_blank">NetGate</a> for instance offers a wide variety of physical devices and cloud solutions that fit security exigences and traffic loads from remote working and small business to large offices, corporate business and data centers.


### Main goals:
<ul>
        <li>install and configure on the <a href="https://www.raspberrypi.com/" target="_blank">Raspberry PI</a> (RPI) a <a href="https://en.wikipedia.org/wiki/Virtual_private_network" target="_blank">VPN</a> server using <a href="https://www.wireguard.com/" target="_blank">Wireguard</a> protocol;</li>
        <li>install and configure on the RPI a network-wide <a href="https://en.wikipedia.org/wiki/Domain_Name_System" target="_blank">DNS</a> sinkhole for blocking ads, tracking, scam, malware and phishing known referrals using <a href="https://pi-hole.net/" target="_blank">Pi Hole</a>;</li>
        <li>configure the RPI to be used as gateway, to block <a href="https://en.wikipedia.org/wiki/IPv6" target="_blank">IPv6</a> traffic for security purposes and hijack hard-coded DNS providers on Smart-TVs.</li>
</ul>


### Secondary goals:
<ul>
        <li>configure <a href="https://wiki.debian.org/UnattendedUpgrades" target="_blank">unattended-upgrades</a> to automate <a href="https://en.wikipedia.org/wiki/Raspberry_Pi_OS" target="_blank">Raspberry Pi OS</a> updates;</li>
        <li>configure the RPI to refuse <a href="https://en.wikipedia.org/wiki/Secure_Shell" target="_blank">SSH</a> password access and use instead a security key token;</li>
        <li>setup <a href="https://en.wikipedia.org/wiki/Network_address_translation" target="_blank">NAT</a> and firewall rules for security purposes and preventing <a href="https://en.wikipedia.org/wiki/DNS_over_TLS" target="_blank">DoT</a> and <a href="https://en.wikipedia.org/wiki/DNS_over_HTTPS" target="_blank">DoH</a> queries;</li>
        <li>configure a <a href="https://en.wikipedia.org/wiki/Dynamic_DNS" target="_blank">DDNS</a> service to access the VPN server through the dynamic public IP address given by your <a href="https://en.wikipedia.org/wiki/Internet_service_provider" target="_blank">ISP</a> from smartphones and laptops while are not connected to the <a href="https://en.wikipedia.org/wiki/Local_area_network" target="_blank">LAN</a>;</li>        
        <li>implement a diagnostic script that checks that services intalled on RPI are working propely;</li>
        <li>implement a <a href="https://en.wikipedia.org/wiki/Watchdog_timer" target="_blank">watchdog timer</a> that regularly checks VPN server and Pi Hole status;</li>
        <li>implement a script to automate the creation and purge of VPN clients and their relative access keys and creates a configuration QR code for smartphones;</li>
        <li>automate the creation of a password protected backup archive of RPI configuration and its upload on Google Drive or other cloud storage services;</li>
        <li>implement a script for manual restore from a password protected backup archive file.</li>
</ul>


### Specs:
Hardware used is a RPI 4 4Gb RAM with a 64Gb microSD memory card, cable connected to my 5G modem/router LAN port, but it can be set to use Wi-Fi connection instead. You’ll also need a microSD card reader.   
The operative system installed on the RPI is Raspberry Pi OS 64bit headless (without desktop environment), based on Linux <a href="https://www.debian.org/releases/bookworm/" target="_blank">Debian Bookworm</a>.   
Required additional Linux software packages from Debian APT: unattended-upgrades, bsd-mailx, nftables, fail2ban, wireguard, qrencode, rclone, ddclient, zip, unzip.   
Required additional software from external source: Pi-Hole.   
PC used for programming client-side uses <a href="https://archlinux.org/" target="_blank">Arch Linux</a> OS.


### 1. – Installing Raspberry Pi OS on a microSD memory card.
<a href="https://www.raspberrypi.com/software/" target="_blank">Raspberry Pi Imager</a> sofware for your preferred OS can be downloaded from Raspberry official website; for Arch Linux can be installed directly from pacman as is part of extra repository.   
Choose your RPI model, the desired version of Raspberry Pi OS and the microSD card of destination.   
After clicking NEXT button, edit the configuration and **enable SSH service** otherwise you will not have access to the RPI if you have chosen an headless OS; change the default *userID* (pi), set an access secure password, locales and keyboard configuration; also setup SSID name, access credentials and country in case you want to connect to the RPI via Wi-Fi.   
The imager will format your microSD card and install selected OS; a message will pop-up after the procedure is finished, telling to remove the microSD card from the reader.


### 2. – First access to RPI.
Insert the microSD card and power up the RPI.   
To access the RPI via SSH you need to provide *userID*, RPI IP address or localhost name and password in a command via terminal that follow this syntax:
```bash
ssh userID@192.168.XXX.XXX
```
You can discover the IP address assigned by router’s <a href="https://en.wikipedia.org/wiki/Dynamic_Host_Configuration_Protocol" target="_blank">DHCP</a> to the RPI by accessing to your router web-admin page or running this command on your Linux client:
```bash
ip neigh show
```
or running this other command if you have nmap installed:
```bash
nmap -sP 192.168.0.0/16
```
NOTE: following this guide you will set a static IP through the RPI configuration, but is always a good practice to reserve a specific static IP address in router’s configuration: it will link the RPI connected device’s <a href="https://en.wikipedia.org/wiki/MAC_address" target="_blank">MAC address</a> to the specified LAN IP address. It should be done for all the clients that will use the RPI for a better control over your network. You can also adjust the DHCP range of your router.   
Once access is gained with password set in Raspberry Pi Imager configuration, execute:
```bash
sudo raspi-config
```
an interactive menu will pop-up; choose “Advanced Settings” (last option on the list) and then “Expand File System”.   
You can navigate menu with ARROW keys, TAB key and confirm with ENTER key.   
Exit the menu and the RPI will reboot to expand the file system to the whole microSD card.   
The connection via SSH from your client terminal to the RPI will be terminated, obviously.


### 3. – Set a static IP address on the RPI.
After rebooting, access again the RPI via SSH and update the RPI executing:
```bash
sudo apt update && sudo apt upgrade -y
```
It will take some time, depending on the amount of the upgrades needed by the system and your internet connection speed.   
After upgrade process has finished, execute this command:
```bash
sudo nmtui
```
from the interactive menu that will show up you will be able to select the connection device you’re using (ethernet or Wi-Fi) and set up a static IP address, gateway and DNS server(s) address(es). If, as suggested, you reserved a static IP address on the router, be sure that the IP address set is the same.   
Reboot the RPI and all configuration changes will take effect:
```bash
sudo reboot
```


### 4. - Configuring unattended-upgrades.
Unattended-upgrades is a Debian software package that automate the download and install of available updates, including the OS version upgrades when released, reboot the system when is required from the updates and auto clean the system from unused software packages, dependecies  and old kernels;   
it needs to be installed, configured to match RPI architecture and activated;   
access the RPI via SSH and execute:
```bash
sudo apt install -y unattended-upgrades bsd-mailx
```
after the installation process is completed, edit the configuration file:
```bash
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```
look for the file section that starts with

>Unattended-Upgrade::Origins-Pattern   

and after last line that starts with

>"origin=Debian,codename=…   

add the two following lines to include RPI architecture to update sources:
```bash
"origin=Raspbian,codename=${distro_codename},label=Raspbian";
"origin=Raspberry Pi Foundation,codename=${distro_codename},label=Raspberry Pi Foundation";
```
scroll down to the section

>//Send mail to this address…   

and set your internal mail address on this line; if its commented with **//** symbols uncomment it otherwise the command will be ignored:

>Unattended-Upgrade::Mail "userID@localhost";   

set these other lines to match following configuration and uncomment it:   
system will send you and internal mail in case of an update error, will automatically remove unused packages, dependencies and old kernels and reboot the system when is required by the update process:

>Unattended-Upgrade::MailReport "only-on-error";   
>Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";   
>Unattended-Upgrade::Remove-New-Unused-Dependencies "true";   
>Unattended-Upgrade::Remove-Unused-Dependencies "true";   
>Unattended-Upgrade::Automatic-Reboot "true";

save file and exit nano editor;   
now you need to perform a “dry run” of unattended-upgrades to check that changes in configuration file are set properly:
```bash
sudo unattended-upgrades -d -v --dry-run
```
and if you’re not getting any error messages you can enable unattended-upgrade process:
```bash
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

### 5. – Set SSH access to the RPI using a security token.
Security key token implements strong security standards to SSH access to your RPI and along with failtoban and ufw that will be configured later prevent access through brute-force attacks on your RPI SSH port; for this purpose you can also change the default port (22) used by SSH protocol.   
First you need to generate the security key token on your Linux client PC:
```bash
ssh-keygen -t rsa
```
you will be asked to give a name to generated security key token;   
both public and private key will be stored in /home/*client_userID*/.ssh/ directory of your Linux client PC;   
copy the token public key to the RPI, adjusting *tokenname*, *RPI_static_IP* and *userID* varibles according to your settings:
```bash
scp ~/.ssh/tokenname_rsa.pub userID@RPI_static_IP:/home/userID/
```
now you need to access to the RPI via SSH and create a file that SSH daemon will look for when you’re trying to access the RPI with the security key token:
```bash
install -d -m 700 ~/.ssh
```
now you can add the token public key to the created **authorized_keys** file:
```bash
cat /home/userID/tokenname_rsa.pub >> ~/.ssh/authorized_keys
```
and then set the correct permission, user and group to the file:
```bash
sudo chmod 644 ~/.ssh/authorized_keys
sudo chown userID:userID ~/.ssh/authorized_keys
```
you need to repeat the steps regarding key token creation, copy public key to the RPI and add it to authorized_key file procedures from all the PCs and laptops you wish to grant SSH key token access to your RPI;   
you can also remove the public key file:
```bash
rm /home/userID/tokenname_rsa.pub
```
after all PCs and laptops keys has been added, you need to edit the SSH configuration file to inhibit access via password:
```bash
sudo nano /etc/ssh/sshd_config
```
look for the line **PasswordAuthentication**, if is commented with **#** symbol uncomment it and set bolean value to **“no”**.   
Save file and exit nano editor (CTRL+O, ENTER, CTRL+X).   
After rebooting the RPI you will need to call the security key token to access the RPI via SSH:
```bash
ssh -i /home/client_userID/.ssh/tokenname_rsa userID@RPI_static_IP
```
SSH security key tokens can be also generated from MacOS, Windows and other operating systems, I’ll leave you the pleasure to do a simple web search to get this knowledge.

### 6. – Install Pi Hole.
The installation process is completely automated and you will be asked only few simple questions to complete the setup and get the Pi Hole working:
```bash
curl -sSL https://install.pi-hole.net | bash
```
don’t forget to take note of the web-admin page password that will be shown at the end of installation process and to refer to Pi Hole official website for documentation, commands, customization and eventual issues.   
To be able to operate, Pi Hole needs blocklists and eventually whitelists of domains; a simple web search will be enough to find many.   
**NOTE:** As YouTube and Twitch serve their ads through their main domains, Pi Hole will NOT be able to block it.   
Now you can set up two <a href="https://en.wikipedia.org/wiki/Cron" target="_blank">cron</a> jobs to automate the update of the Pi Hole and the Pi Hole blocklists (Gravity):
```bash
sudo crontab -e
```
if this is your first access to crontab you will be asked to choose an editor from a list;   
add this two lines that you can customize to fit your preference:   
the first line sets the blocklists update at 4:00 AM every 3rd day of the week;   
second line sets Pi Hole update at 5:00 AM every 3rd day of the week;
```bash
0 4 * * 3 /bin/bash /home/userID/ya-pihole-list/adlists-updater.sh 1 >/dev/null
0 5 * * 3 /usr/bin/date >> /var/log/pihole_update.log && /usr/local/bin/pihole -up >> /var/log/pihole>
```
save the crontab file and exit editor;   
now you can reboot the RPI and all changes will take effect;   
you need to set your network clients to use *RPI_static_IP* as DNS address or you can set it as DNS address directly on your router settings so it will be used network-wide.

### 7. – Install and configure NAT and firewall rules, gateway, Wireguard VPN, and DDNS.
This script will provide the installation of necessary software packages and the configuration of various services like Wireguard VPN server, disable IPv6 traffic for security purposes, sets nftables rules to use the RPI as gateway and hijack hard-coded DNS providers in Smart-TV, sets firewall and failtoban rules and configures ddclient to access your VPN server while your smartphones or laptops are not connected to the LAN if your ISP gives you a dynamic IP address.   
While is quite simple to disable IPv6 traffic through the configuration of the network manager on your PC or laptop, and also many Smart-TV models give the oprion in their network settings, is way more difficult on your smartphone because it will probably require root privileges; setting the RPI as your gateway while your smartphone is connected to the LAN or VPN will block all IPv6 traffic.   
You need to forward the udc port you will use for your VPN server (51234 in this example) from the exterior to your RPI_static_IP in your router configuration; if your router does not have port forwarding function, it will probably have virtual server function where you can set the same rule.   
**NOTE:** the VPN you are installing will **NOT** hide your public IP address; it will only encrypt the communications from your device to the destination you're reaching, avoiding third parties to be able to intercept your data. To hide your public IP or de-geolocalize it for purposes like see Netflix content not available in your country, you'll need a commercial VPN subscription, that gives you the chance to connect to servers located in different countries; there's a wide variety of offers in the VPN market, but providers that are unanimously considered the best ones privacy-wise are swedish <a href="https://mullvad.net" target="_blank">Mullvad</a> and swiss <a href="https://protonvpn.com/" target="_blank">Proton</a> due to the strict privacy laws of coutries they're operating from.   
With rules set in nftables and previous configuration of SSH access only with security key token, SSH port is already protected from brute-force attacks and is also not exposed to WAN direct access, but can be only reached from LAN or VPN addresses; fail2ban is installed only for auditing/forensic purposes on failed access logs, but will be useful if you will change rule settings on SSH port.   
For ddclient configuration, you will need some parameters that can be obtained from the control panel of DDNS provider service you subscribed, like protocol used, username, password and third level domain you have chosen.   
If you have a static public IP you can skip ddclient configuration with CTRL+C.   
You can check your IP address and active interface name executing this command on the RPI:
```bash
ip -brief addr
```
Create a shell file:
```bash
sudo nano install_services.sh
```
and copy the following script, adjusting the variables in the beginning to fit your settings:   
*eht0* is the variable value if your RPI is cable connected, if you're using Wi-Fi connection should be set to *wlan0*;   
*wg0* is the virtual device that will be created and used for VPN tunneling and *10.8.0.0/24* is the subnet that will be used by the VPN; *10.8.0.1* will be your VPN gateway address; this values are WireGuard defaults;
<!-- BEGIN install_services.sh -->
```bash
#!/bin/bash

set -e

# === VARIABLES TO MODIFY ===
# you can check the RPI IP and device name (IFACE) with this command
# ip -brief addr | grep UP
PIHOLE_IP="RPI_static_IP"
IFACE="eth0"
VPN_PORT="51234"
WG_IFACE="wg0"
VPN_SUBNET="10.8.0.0/24"

echo "Starting setup Raspberry Pi as gateway/VPN with safe nftables"

# === 1. Disable IPv6 ===
echo "Disabling IPv6..."
cat <<EOF | sudo tee /etc/sysctl.d/99-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sudo sysctl -p /etc/sysctl.d/99-disable-ipv6.conf

# === 2. Enable IP forwarding ===
echo "Enabling IP forwarding..."
sudo sed -i '/^#net.ipv4.ip_forward=1/c\net.ipv4.ip_forward=1' /etc/sysctl.conf
sudo sysctl -w net.ipv4.ip_forward=1

# === 3. Install software packages ===
echo "Installing wireguard, nftables, fail2ban, ddclient..."
sudo apt update
sudo apt install -y wireguard nftables fail2ban ddclient qrencode

# === 5. Configure nftables ===
# With this rule set only incoming requests from LAN and VPN are allowed
# with the exception for port used by VPN and DDNS
# Also SSH port will be reachable only from LAN/VPN.
echo "Creating persistent nftables configuration..."

NFT_CONF="/etc/nftables.conf"

sudo tee "$NFT_CONF" > /dev/null <<EOF
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0;
        policy drop;

        iif "lo" accept
        ct state established,related accept

        # LAN and VPN - full access
        ip saddr 192.168.0.0/16 accept
        ip saddr 10.8.0.0/24 accept

        # WireGuard port (VPN access)
        udp dport $VPN_PORT accept

        # SSH access only from LAN and VPN
        ip saddr { 192.168.0.0/16, 10.8.0.0/24 } tcp dport 22 accept
        tcp dport 22 drop

        # Log and final drop
        log prefix "nftables input drop: " flags all counter
        drop
    }

    chain forward {
        type filter hook forward priority 0;
        policy drop;

        ct state established,related accept
        ip saddr 10.8.0.0/24 accept
        ip daddr 10.8.0.0/24 accept
        ip saddr 192.168.0.0/16 oifname "$IFACE" accept
    }

    chain output {
        type filter hook output priority 0;
        policy accept;

        # Block DNS-over-TLS
        tcp dport 853 drop

        # Block DNS-over-HTTPS
        ip daddr { 1.1.1.1, 1.0.0.1, 8.8.8.8, 8.8.4.4, 9.9.9.9 } tcp dport 443 drop
        ip6 daddr { 2606:4700:4700::1111, 2001:4860:4860::8888 } tcp dport 443 drop
    }
}

table ip nat {
    chain prerouting {
        type nat hook prerouting priority 0;

        # DNS hijack toward Pi-hole
        tcp dport 53 dnat to $PIHOLE_IP
        udp dport 53 dnat to $PIHOLE_IP
    }

    chain postrouting {
        type nat hook postrouting priority 100;

        ip saddr 10.8.0.0/24 oifname "$IFACE" masquerade
        ip saddr 192.168.0.0/16 oifname "$IFACE" masquerade
    }
}
EOF


sudo systemctl enable nftables
sudo systemctl start nftables

# === 6. Configure Wireguard server ===
echo "Configuring WireGuard server..."
WG_DIR="/etc/wireguard"
sudo mkdir -p "$WG_DIR"
cd "$WG_DIR"

if [[ ! -f server.key ]]; then
    umask 077
    wg genkey | tee server.key | wg pubkey > server.pub
fi

PRIVATE_KEY=$(cat server.key)

cat <<EOF | sudo tee "$WG_DIR/$WG_IFACE.conf" > /dev/null
[Interface]
PrivateKey = $PRIVATE_KEY
Address = 10.8.0.1/24
ListenPort = $VPN_PORT
EOF

sudo systemctl enable "wg-quick@$WG_IFACE"
sudo systemctl start "wg-quick@$WG_IFACE"

# === 7. Configure fail2ban ===
echo "Configuring Fail2Ban..."
cat <<EOF | sudo tee /etc/fail2ban/jail.d/ssh.conf
[sshd]
enabled = true
port = ssh
filter = sshd
backend = systemd
maxretry = 5
EOF

sudo systemctl restart fail2ban

# === 8. Configure ddclient ===
# If your internet connection has a static IP address you can cmment next four script lines
# and last line, with # symbol at beginning of the lines;
# you can also uninstall ddclient: sudo apt --purge remove -y ddclient
echo "Configuring ddclient"
echo "Press Ctrl+C for skip, or wait to configure."
sleep 10
sudo dpkg-reconfigure ddclient

echo "Success!"
echo "- IPv6 traffic blocked"
echo "- IP forwarding enabled"
echo "- nftables: NAT, DNS hijack, DoH/DoT and firewall rules applied"
echo "- WireGuard: ready over port $VPN_PORT"
echo "- Fail2Ban: active"
echo "- ddclient: configured"

```
<!-- END install_services.sh -->
save the file and exit the editor;   
make the file executable:   
```bash
sudo chmod +x install_services.sh
```
and execute the script to install and configure services:   
```bash
sudo ./install_services.sh
```
after the script has finished services installaion you need to reboot the RPI.

### 8. - CGNAT and NAT2
ISP implements security features on the internet line you purchase and most common are CGNAT and double NAT or NAT2, that are used mainly when you have a dynamic public IP address.   
With those features configured on your internet line you will be unable to access the RPI from the WAN and consequentially you will be also unable to use your Wireguard VPN when you're not connected to LAN.  
The following shell script will help you to check your internet line and know if you are under CGNAT or NAT2;   
first you need to create a shell file:
```bash
nano cgnat_check.sh
```
copy following script and paste it into nano editor:
<!-- BEGIN cgnat_check.sh -->
```bash
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

```
<!-- END cgnat_check.sh -->
make the script executable:
```bash
chmod +x cgnat_check.sh
```
and run the scropt with:
```bash
sudo ./cgnat_check.sh
```
If you want also to check the correct forwarding of VPN/DDNS **udp** port (51234) from WAN to your RPI you can use <a href="https://www.yougetsignal.com/tools/open-ports/" target="_blank">YouGetSignal</a> web tool.   
In case you're under CGNAT or NAT2 you can check with your ISP the possibility to change from dynamic to static public IP address; this will probably involve some fees.   
If your ISP configured a NAT2 on your line it probably offers the function of port forwarding through a control panel or upon request.   
If you are under CGNAT and your ISP can't give you a static public IP address, if you are under NAT2 and your ISP don't allow port forwarding function and if you can't or don't want to change to a different ISP that offers those options, there's a workaround: you can subscribe for an online Linux VPS service; with a web search you can find many offers on the VPS market; there are some free solution even from tech colossus like Google and Oracle. Paid services for the specs you'll need will cost you € 1,00 per month.   
VPS online server will give you a static IPv6 address; you can install wireguard on VPS, with a different subnet and udp port from one you have installed on RPI, to act as server and install a client on RPI that will automatically connect to the VPS creating a tunneled connection; then you can route all traffic from VPS to RPI. In this way you can use your smartphone, tablet or laptop, configured as client of RPI VPN server that you configured in previous chapter, to use the VPS IPv6 static address to connect to the RPI and activate its VPN tunnel, bypassing CGNAT or NAT2 from your ISP.   


### 9. - Implement a manual diagnostic script to check installed services and rules.
This script, when launched, will check that services you installed are working properly.   
change variables in the beginnig of file according to your settings;   
First you need to create a shell file:
```bash
sudo nano /usr/local/bin/diagnostic.sh
```
copy follwing code an paste into the shell file:
<!-- BEGIN diagnostic.sh -->
```bash
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

```
<!-- END diagnostic.sh -->
save file, exit nano editor and make shell file executable:
```bash
sudo chmod +x /usr/local/bin/diagnostic.sh
```
you can launch the diagnostic scrip with:
```bash
sudo diagnostic.sh
```

### 10. - Create a watchdog timer to check VPN server and Pi Hole status.
Watchdog timer is a useful service that regularly checks the operational status of the VPN server and Pi Hole, and restore it in case of failure.   
You first need to creae a shell file:
```bash
sudo nano /usr/local/bin/watchdog.sh
```
and copy following code into it:
<!-- BEGIN watchdog.sh -->
```bash
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
```
<!-- END watchdog.sh -->
save file and exit nano, then make the file executable:
```bash
sudo chmod +x /usr/local/bin/watchdog.sh
```
Now you need to create two ini files to allow the watchdog timer to work:
```bash
sudo nano /etc/systemd/system/pi-vpn-watchdog.service
```
and copy following code into it:
<!-- BEGIN pi-vpn-watchdog.service -->
```bash
[Unit]
Description=Watchdog for Pi-hole and WireGuard
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/watchdog.sh

[Install]
WantedBy=multi-user.target
```
<!-- END pi-vpn-watchdog.service -->
save file and exit nano;
```bash
sudo nano /etc/systemd/system/pi-vpn-watchdog.timer
```
and copy following code into it:
<!-- BEGIN pi-vpn-watchdog.timer -->
```bash
[Unit]
Description=Execute Watchdog every 2 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=2min
Unit=pi-vpn-watchdog.service

[Install]
WantedBy=timers.target
```
<!-- END pi-vpn-watchdog.timer -->
save file and exit nano.   
Now you need to reload daemon and enable the new service so it will be automatically loaded on every RPI boot:
```bash
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now pi-vpn-watchdog.timer
```

