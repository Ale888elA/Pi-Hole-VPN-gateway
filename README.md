## Using a Raspberry Pi as a VPN server, Gateway and DNS sinkhole
This guide is suited for the security exigences of a home network and for private use; in a business environment, especially if you deal with customer’s sensible data, is strongly advised to use a professional device that uses pfsense firewall software and strong VPN encryption; <a href="https://www.netgate.com/" target="_blank">NetGate</a> for instance offers a wide variety of physical devices and cloud solutions that fit security exigences and traffic loads from remote working and small business to large offices, corporate business and data centers.


### Main goals:
<ul>
        <li>install and configure on the <a href="https://www.raspberrypi.com/" target="_blank">Raspberry PI</a> (RPI) a <a href="https://en.wikipedia.org/wiki/Virtual_private_network" target="_blank">VPN</a> server using <a href="https://www.wireguard.com/" target="_blank">Wireguard</a> protocol;</li>
        <li>install and configure on the RPI a network-wide <a href="https://en.wikipedia.org/wiki/Domain_Name_System" target="_blank">DNS</a> sinkhole for blocking ads, tracking, scam, malware and phishing known referrals using <a href="https://pi-hole.net/" target="_blank">Pi Hole</a>;</li>
        <li>configure the RPI to be used as gateway, to block <a href="https://en.wikipedia.org/wiki/IPv6" target="_blank">IPv6</a> traffic for security purposes and hijack hard-coded DNS providers on Smart-TVs;</li>
        <li>cover every aspects of RPI environment program-wise, from updates to backup and automated checks of running instances, so once you finished programming you can forget to check if its working.</li>
</ul>


### Secondary goals:
<ul>
        <li>configure <a href="https://wiki.debian.org/UnattendedUpgrades" target="_blank">unattended-upgrades</a> to automate <a href="https://en.wikipedia.org/wiki/Raspberry_Pi_OS" target="_blank">Raspberry Pi OS</a> updates;</li>
        <li>configure the RPI to refuse <a href="https://en.wikipedia.org/wiki/Secure_Shell" target="_blank">SSH</a> password access and use instead a security key;</li>
        <li>setup <a href="https://en.wikipedia.org/wiki/Network_address_translation" target="_blank">NAT</a> and firewall rules for security purposes and preventing <a href="https://en.wikipedia.org/wiki/DNS_over_TLS" target="_blank">DoT</a> and <a href="https://en.wikipedia.org/wiki/DNS_over_HTTPS" target="_blank">DoH</a> queries;</li>
        <li>configure a <a href="https://en.wikipedia.org/wiki/Dynamic_DNS" target="_blank">DDNS</a> service to access the VPN server through the dynamic public IP address given by your <a href="https://en.wikipedia.org/wiki/Internet_service_provider" target="_blank">ISP</a> from smartphones, tablets and laptops while are not connected to the <a href="https://en.wikipedia.org/wiki/Local_area_network" target="_blank">LAN</a>;</li>        
        <li>implement a diagnostic script that checks that services intalled on RPI are working propely;</li>
        <li>implement a <a href="https://en.wikipedia.org/wiki/Watchdog_timer" target="_blank">watchdog timer</a> that regularly checks VPN server and Pi Hole status;</li>
        <li>implement a script to automate the creation and purge of VPN clients, their relative access keys and and configuration files,that also shows a configuration QR code for smartphones and tablets;</li>
        <li>automate the creation of a password protected backup archive of RPI configuration and its upload on a cloud storage service;</li>
        <li>implement a script for manual restore from a password protected backup archive file.</li>
</ul>


### Specs:
Hardware used is a RPI 4 with 4Gb RAM and 64Gb microSD memory card, cable connected to my 5G modem/router LAN port, but it can be set to use Wi-Fi connection instead. You’ll also need a microSD card reader.   
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


### 5. – Set SSH access to the RPI using a security key.
Security key implements strong security standards to SSH access to your RPI and along with failtoban and firewall rules that will be configured later prevent access through brute-force attacks on your RPI SSH port; for this purpose you can also change the default port (22) used by SSH protocol.   
First you need to generate the security key on your Linux client PC:
```bash
ssh-keygen -t rsa
```
you will be asked to give a name to generated security key;   
both public and private key will be stored in /home/*client_userID*/.ssh/ directory of your Linux client PC;   
copy the public key to the RPI, adjusting *keyname*, *RPI_static_IP* and *userID* varibles according to your settings:
```bash
scp ~/.ssh/keyname_rsa.pub userID@RPI_static_IP:/home/userID/
```
now you need to access to the RPI via SSH and create a file that SSH daemon will look for when you’re trying to access the RPI with the security key:
```bash
install -d -m 700 ~/.ssh
```
now you can add the public key to the created **authorized_keys** file:
```bash
cat /home/$(logname)/keyname_rsa.pub >> ~/.ssh/authorized_keys
```
and then set the correct permission, user and group to the file:
```bash
sudo chmod 644 ~/.ssh/authorized_keys
sudo chown $(logname):$(logname) ~/.ssh/authorized_keys
```
you need to repeat the steps regarding key creation, copy public key to the RPI and add it to authorized_key file procedures from all the PCs and laptops you wish to grant SSH key access to your RPI;   
you can also remove the public key file:
```bash
rm /home/$(logname)/keyname_rsa.pub
```
after all PCs and laptops keys has been added, you need to edit the SSH configuration file to prevent access via password:
```bash
sudo nano /etc/ssh/sshd_config
```
look for the line **PasswordAuthentication**, if is commented with **#** symbol uncomment it and set bolean value to **“no”**.   
Save file and exit nano editor (CTRL+O, ENTER, CTRL+X).   
After rebooting the RPI you will need to call the security key to access the RPI via SSH:
```bash
ssh -i /home/$(logname)/.ssh/keyname_rsa userID@RPI_static_IP
```
SSH security keys can be also generated from MacOS, Windows and other operating systems, I’ll leave you the pleasure to do a simple web search to get this knowledge.


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
With rules set in nftables and previous configuration of SSH access only with security key, SSH port is already protected from brute-force attacks and is also not exposed to WAN direct access, but can be only reached from LAN or VPN addresses; fail2ban is installed only for auditing/forensic purposes on failed access logs, but will be useful if you will change rule settings on SSH port.   
For ddclient configuration, you will need some parameters that can be obtained from the control panel of DDNS provider service you subscribed, like protocol used, username, password and third level domain you have chosen.   
If you have a static public IP you can skip ddclient configuration with CTRL+C.   
From the home directory of RPI (home/userID/) copy the following command and paste it in the terminal; it will download the <a href="https://github.com/Ale888elA/Pi-Hole-VPN-gateway/blob/main/scripts/install_services.sh" target="_blank">install_services.sh</a> script to your home directory: 
```bash
wget https://github.com/Ale888elA/Pi-Hole-VPN-gateway/raw/main/scripts/install_services.sh
```
if you don't want to use default variables value edit the script with nano:
```bash
sudo nano install_services.sh
```
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
ISP implements security features on the internet line you subscribed for and most common are CGNAT and double NAT or NAT2, that are used when it gives you a dynamic public IP address.    
With those features configured on your internet line you will be unable to access the RPI from the WAN and consequentially you will be also unable to use your Wireguard VPN when you're not connected to LAN.    
The following shell script will help you to check your internet line and know if you are under CGNAT or NAT2;    
From the home directory of RPI (home/userID/) copy the following command and paste it in the terminal; it will download the <a href="https://github.com/Ale888elA/Pi-Hole-VPN-gateway/blob/main/scripts/cgnat_check.sh" target="_blank">cgnat_check.sh</a> script to your home directory: 
```bash
wget https://github.com/Ale888elA/Pi-Hole-VPN-gateway/raw/main/scripts/cgnat_check.sh
```
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
If you are under CGNAT and your ISP can't give you a static public IP address, if you are under NAT2 and your ISP don't allow port forwarding function and if you can't or don't want to change to a different ISP that offers those options, there's a workaround: you can subscribe for an online Linux VPS service; with a web search you can find many offers on the VPS market, and also a lot of scams, so choose your VPS service provider wisely; there are some free solution even from tech colossus like Google and Oracle. Paid services for the specs you'll need will cost you € 1,00 per month.    
VPS online server will give you a static IP address; you can install wireguard on VPS, with a different subnet from one you have installed on RPI, to act as server and install a client on RPI that will automatically connect to the VPS creating an encrypted tunnel connection; then you can route all traffic from VPS to RPI. In this way you can use your smartphone, tablet or laptop, configured as client of RPI VPN server that you set up in previous chapter, to use the VPS static public IP address to connect to the RPI and activate their VPN tunnels, bypassing CGNAT or NAT2 from your ISP.    
Most, if not all, VPS server are configured to accept SSH only with security key given when you open an account, to prevent prute-force attacks. Access your VPS server via SSH and execute this command to check if wget is installed; if sudo command don't work due to VPS configuration, gain root privileges executing command "su", and remove "sudo" part in following commands:
```bash
sudo apt update && sudo apt install -y wget
```
Download the <a href="https://github.com/Ale888elA/Pi-Hole-VPN-gateway/blob/main/scripts/VPS_server.sh" target="_blank">VPS_server.sh</a> script; it will install Wireguard software, configure a virtual device called "wg_cgnat" that listen over udp port "51234", configure the VPS server as VPN server and forward traffic to RPI client that will be configured later, configure firewall rules to block all incoming traffic except over udp 51234 port and tcp 22 port (SSH) and configure fail2ban to block SSH access tries with password:
```bash
wget https://github.com/Ale888elA/Pi-Hole-VPN-gateway/raw/main/scripts/VPS_server.sh
```
make the script executable:
```bash
sudo chmod +x VPS_server.sh
```
and run the scropt with:
```bash
sudo ./VPS_server.sh
```
once the script finished the installation and configuration process, copy the VPS public key shown to add it to VPS client configuration.    
Now, log in to your RPI and download the <a href="https://github.com/Ale888elA/Pi-Hole-VPN-gateway/blob/main/scripts/VPS_client.sh" target="_blank">VPS_client.sh</a> script; it will configure the virtual device "wg_cgnat" and add the configuration to RPI to act as a client of VPS server and receive forwarded traffic;
```bash
wget https://github.com/Ale888elA/Pi-Hole-VPN-gateway/raw/main/scripts/VPS_client.sh
```
edit the script, add the VPS public key and the VPS static public IP address:
```bash
sudo nano VPS_client.sh
```
save file, exit editor and make the script executable:
```bash
sudo chmod +x VPS_client.sh
```
run the scropt with:
```bash
sudo ./VPS_client.sh
```
when script finished the configuration process, copy RPI public key shown and add it to wg_cgnat.conf file on VPS server.    
Access VPS server via SSH and edit configuration file:
```bash
sudo nano /etc/wireguard/wg_cgnat.conf
```
paste RPI public key from RPI client configuration and reboot the VPS server to make changes effective.    
Back to tour RPI edit nftables configuration file:
```bash
sudo nano /etc/nftables.conf
```
look for this section of the script:   

> table inet filter {    
>    chain input {    
>        type filter hook input priority 0;    
>        policy drop;    
>        iif "lo" accept    
>        ct state established,related accept     

and add following rule after the lines above to accept connection coming from your VPS server:
```bash
iif "wg_cgnat" ip saddr 10.100.100.1 accept
```
Save file, exit editor and restart the RPI to make all changes effective.


### 9. - Add and remove VPN peer (client)
This shell script will act as VPN client manager, giving you the options to:
<ol type="1">
        <li>create a new VPN peer looking for first available VPN address, generate access keys and configuration file and display a configuration QR code that can be red from smartphones and tablets using official Wireguard app for Android or iOS;</li>
        <li>delete an existing peer with its access keys and configuration file, typing its name from a displayed list of configured peers.</li>
</ol>
You need to set the variables at the beginnig of the script according to your settings:<br>     
<ul>
        <li>if your internet line has a static public IP address and the VPN UDP port is forwarded by router settings, set as ENDPOINT your static public IP address;</li>
        <li>if your internet line has a dynamic public IP address but its NOT under CGNAT, your ISP allowed VPN UDP port forwarding if its under NAT2, the VPN UDP port is forwarded by router settings and you configured ddclient, you should set as ENDPOINT the third level domain you got from your DDNS service;</li>
        <li>if you have configured a VPN on VPS that forwards traffic to the the RPI as its client, you should set as ENDPOINT the VPS static public IP address or domain;</li>
        <li>otherwise set as ENDPOINT the RPI_static_IP, but it will work ONLY when clients are connected to LAN.</li>
</ul>   
From the home directory of RPI (home/userID/) copy the following command and paste it in the terminal; it will download the <a href="https://github.com/Ale888elA/Pi-Hole-VPN-gateway/blob/main/scripts/wg_client_manager.sh" target="_blank">wg_client_manager.sh</a> script to your home directory:   

```bash
wget https://github.com/Ale888elA/Pi-Hole-VPN-gateway/raw/main/scripts/wg_client_manager.sh
```
open the script with nano and change the variables in the beginning of the file to match your settings:
```bash
sudo nano wg_client_manager.sh
```
save the file and exit nano;    
make the file executable and move it to a more appropriate directory:
```bash
sudo chmod +x wg_client_manager.sh
sudo mv wg_client_manager.sh /usr/local/bin/
```
run the script with:
```bash
sudo wg_client_manager.sh
```
To use the VPN connection from your Linux client PC you need to install Wireguard software and copy the VPN client configuration file from /etc/wireguard/clients/ folder of your RPI;    
to activate the VPN tunnel you can use a lightweight and very straightforward GUI called <a href="https://github.com/UnnoTed/wireguird" target="_blank">Wireguird</a>, but there are also other GUI options, or you can use a command line via terminal.   


### 10. - Implement a manual diagnostic script to check installed services and rules.
This script, when launched, will check that services you installed are working properly.   
change variables in the beginnig of file according to your settings;   
From the home directory of RPI (home/userID/) copy the following command and paste it in the terminal; it will download the <a href="https://github.com/Ale888elA/Pi-Hole-VPN-gateway/blob/main/scripts/diagnostic.sh" target="_blank">diagnostic.sh</a> script to your home directory: 
```bash
wget https://github.com/Ale888elA/Pi-Hole-VPN-gateway/raw/main/scripts/diagnostic.sh
```
if you did not used default variables value, open the script with nano and change the values in the beginning of the file to match your settings:
```bash
sudo nano diagnostic.sh
```
make the file executable and move it to a more appropriate directory:
```bash
sudo chmod +x diagnostic.sh
sudo mv diagnostic.sh /usr/local/bin/
```
run the script with:
```bash
sudo diagnostic.sh
```


### 11. - Create a watchdog timer to check VPN server and Pi Hole status.
Watchdog timer is a useful service that regularly checks the operational status of the VPN server and Pi Hole, and restore it in case of failure.   
From the home directory of RPI (home/userID/) copy the following command and paste it in the terminal; it will download the <a href="https://github.com/Ale888elA/Pi-Hole-VPN-gateway/blob/main/scripts/diagnostic.sh" target="_blank">watchdog.sh</a> script, <a href="https://github.com/Ale888elA/Pi-Hole-VPN-gateway/blob/main/scripts/pi-vpn-watchdog.service" target="_blank">pi-vpn-watchdog.service</a> and <a href="https://github.com/Ale888elA/Pi-Hole-VPN-gateway/blob/main/scripts/pi-vpn-watchdog.timer" target="_blank">pi-vpn-watchdog.timer</a> ini files to your home directory: 
```bash
wget https://github.com/Ale888elA/Pi-Hole-VPN-gateway/raw/main/scripts/watchdog.sh
wget https://github.com/Ale888elA/Pi-Hole-VPN-gateway/raw/main/scripts/pi-vpn-watchdog.service
wget https://github.com/Ale888elA/Pi-Hole-VPN-gateway/raw/main/scripts/pi-vpn-watchdog.timer
```   
make the script watchdog.sh executable and move it to the appropriate directory:
```bash
sudo chmod +x watchdog.sh
sudo mv watchdog.sh /usr/local/bin/
```
move the two ini files to the appropriate directory:
```bash
sudo mv pi-vpn-watchdog.service /etc/systemd/system/
sudo mv pi-vpn-watchdog.timer /etc/systemd/system/
```
Now you need to reload daemon and enable the new service so it will be automatically loaded on every RPI boot:
```bash
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable pi-vpn-watchdog.timer
sudo systemctl start pi-vpn-watchdog.timer
```

### 12. - Create a system backup and upload it to cloud storage service.
This script will perform a backup of all settings you configured following this guide including: unattended-upgrades, SSH access public key, nftables rules, Wireguard (configuration, clients and keys), Pi Hole (configuration and blocklists), watchdog timer, ddclient, rclone and all custom scripts you stored in /usr/local/bin/ folder of your RPI; then will create an encrypted archive and upload it to your favorite cloud storage service using rclone software.   
As configuration process may differ from one storage service to another, pleae refer to <a href="https://rclone.org/docs/" target="_blank">rclone manual</a> to configure the software and setup your storage service to accept your archive file (you probably need to enable some APIs).   
You can start the configuration process launching:
```bash
rclone config
```
After configuration process has finished, if you need to launch it again to change some parameters and previous command gives you errors, execute:
```bash
sudo rclone config --config /home/$(logname)/.config/rclone/rclone.conf
```
The backup script is fully automated, you just need to set as variable the name of the folder you configured on your cloud storage drive where backup files will be uploaded.    
During first run you will be asked to set a password to encrypt the backup archives; it will be stored in the system and file permission will be changed so only root will be able to read it; take a note of the password anyway.   
The script has also a function to delete from your cloud storage backup files older thant 15 days.    
Copy this command to download the <a href="https://github.com/Ale888elA/Pi-Hole-VPN-gateway/blob/main/scripts/backup.sh" target="_blank">backup.sh</a> script to your RPI home folder:   
```bash
wget https://github.com/Ale888elA/Pi-Hole-VPN-gateway/raw/main/scripts/backup.sh
```
edit the script with nano and set cloud storage folder name varible according to your settings:
```bash
sudo nano backup.sh
```
save file and exit nano;    
make the script executable and move it to the appropriate directory:
```bash
sudo chmod +x backup.sh
sudo mv backup.sh /usr/local/bin/
```
run the script with:
```bash
sudo backup.sh
```
You can set a cron job to automatically launch the backup once a week:
open crontab;
```bash
sudo crontab -e
```
add this line to execute backup process at 4 AM every 6th day of the week (saturday):
```bash
0 4 * * 6 /usr/local/bin/backup.sh
```
save crontab file and exit editor; reboot the RPI to make changes to crontab effective.    


### 13. - Creating a restore script.
This restore script will help you to restore the configrations you set in previous chapters of this guide. You can choose from a full system restore to the restore of a single feature, like wireguard configuration or nftables configuration. It will also ask you if you want to restore from a cloud saved backup file, directly with rclone or providing a link to the cloud backup archive, or from a local backup file from home folder of the RPI.    
If the script will not find the decrypting backup archive password it will automatically start a full restore.    
In case of a full restore, that will be necessary if you re-install the Raspberry Pi OS, you just need to expand the file system on the microSD card and set the RPI static IP address with nmtui like explained in chapters 2 and 3 of the guide, and restore script will do all the rest, including setting the IP forward, block IPv6 protocol, seting SSH acces with your security key, restoring your cron jobs and enable daemon services.    
After the restoring process is complete it will also ask if you want to clean files in temporary folder used for the process and restart the RPI to make all changes effective.    
Copy this command to download the <a href="https://github.com/Ale888elA/Pi-Hole-VPN-gateway/blob/main/scripts/restore.sh" target="_blank">restore.sh</a> script to your RPI home folder:   
```bash
wget https://github.com/Ale888elA/Pi-Hole-VPN-gateway/raw/main/scripts/restore.sh
```
make the script executable and move it to the appropriate directory:
```bash
sudo chmod +x restore.sh
sudo mv restore.sh /usr/local/bin/
```
run the script with:
```bash
sudo restore.sh
```
