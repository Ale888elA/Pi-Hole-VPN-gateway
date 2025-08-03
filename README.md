## Using a Raspberry Pi as a VPN server, Gateway and DNS sinkhole
This guide is suited for the security exigences of a home network and for private use; in a business environment, especially if you deal with customer’s sensible data, is strongly advised to use a professional device that uses pfsense firewall software and strong VPN encryption; NetGate for instance offers a wide variety of devices and cloud solutions that fit security exigences and traffic loads from remote working and small business to large offices, corporate business and data centers.

### Main goals:
<ul>
        <li>install and configure on the <a href="https://www.raspberrypi.com/" target="_blank">Raspberry PI</a> (<abbr title="Raspberry PI">RPI</abbr>) a <a href="https://en.wikipedia.org/wiki/Virtual_private_network" target="_blank"><abbr title="Virtual Private Network">VPN</abbr></a> server using <a href="https://www.wireguard.com/" target="_blank">Wireguard</a> protocol;</li>
        <li>install and configure on the <abbr title="Raspberry PI">RPI</abbr> a network-wide <a href="https://en.wikipedia.org/wiki/Domain_Name_System" target="_blank"><abbr title="Domain Name System">DNS</abbr></a> sinkhole for blocking ads, tracking, scam, malware and phishing known referrals using <a href="https://pi-hole.net/" target="_blank">Pi Hole</a>;</li>
        <li>configure the <abbr title="Raspberry PI">RPI</abbr> to be used as gateway, to block <a href="https://en.wikipedia.org/wiki/IPv6" target="_blank"><abbr title="Internet Protocol version 6">IPv6</abbr></a> traffic for security purposes and hijack hard-coded <abbr title="Domain Name System">DNS</abbr> providers on Smart-TVs.</li>
</ul>

### Secondary goals:
<ul>
        <li>configure <a href="https://wiki.debian.org/UnattendedUpgrades" target="_blank">unattended-upgrades</a> to automate <a href="https://en.wikipedia.org/wiki/Raspberry_Pi_OS" target="_blank">Raspberry Pi OS</a> updates;</li>
        <li>configure the <abbr title="Raspberry PI">RPI</abbr> to refuse <a href="https://en.wikipedia.org/wiki/Secure_Shell" target="_blank"><abbr title="Secure Shell">SSH</abbr></a> password access and use instead a security key token;</li>
        <li>setup <a href="https://en.wikipedia.org/wiki/Network_address_translation" target="_blank"><abbr title="Network Address Translation">NAT</abbr></a> and firewall rules for security purposes and preventing <a href="https://en.wikipedia.org/wiki/DNS_over_TLS" target="_blank"><abbr title="DNS over TLS">DoT</abbr></a> and <a href="https://en.wikipedia.org/wiki/DNS_over_HTTPS" target="_blank"><abbr title="DNS over HTTPS">DoH</abbr></a> queries;</li>
        <li>configure a <a href="https://en.wikipedia.org/wiki/Dynamic_DNS" target="_blank"><abbr title="Dynamic DNS">DDNS</abbr></a> service to access the <abbr title="Virtual Private Network">VPN</abbr> server through the dynamic public IP address given by your <a href="https://en.wikipedia.org/wiki/Internet_service_provider" target="_blank"><abbr title="Internet Service Provider">ISP</abbr></a> from smartphones and laptops while are not connected to the <a href="https://en.wikipedia.org/wiki/Local_area_network" target="_blank"><abbr title="Local Area Network">LAN</abbr></a>;</li>        
        <li>implement a <a href="https://en.wikipedia.org/wiki/Watchdog_timer" target="_blank">watchdog timer</a> that regularly checks the <abbr title="Virtual Private Network">VPN</abbr> server status;</li>
        <li>automate the creation of a password protected backup archive of <abbr title="Raspberry PI">RPI</abbr> configuration and the upload on Google Drive or other cloud storage services;</li>
        <li>implement a script to automate the creation of new <abbr title="Virtual Private Network">VPN</abbr> clients assigning an unused <abbr title="Virtual Private Network">VPN</abbr> IP address and creating a configuration QR code for smartphones;</li>
        <li>implement a script to automate the purge of <abbr title="Virtual Private Network">VPN</abbr> created clients and their keys;</li>
        <li>implement a daemon service that flushes <abbr title="Network Address Translation">NAT</abbr> rules on <abbr title="Raspberry PI">RPI</abbr> boot;</li>
        <li>implement a script for manual diagnosis of the <abbr title="Raspberry PI">RPI</abbr>;</li>
        <li>implement a script for manual restore from a password protected backup archive file.</li>
</ul>

### Specs:
Hardware used is a <abbr title="Raspberry PI">RPI</abbr> 4 4Gb RAM with a 64Gb microSD memory card, cable connected to my 5G modem/router <abbr title="Local Area Network">LAN</abbr> port, but it can be set to use Wi-Fi connection instead. It will also works on RPI 3 models. You’ll also need a microSD card reader.<br>
The operative system installed on the <abbr title="Raspberry PI">RPI</abbr> is Raspberry Pi OS 64bit headless (without desktop environment), based on Linux Debian Bookworm.<br>
Required additional Linux software packages from APT: unattended-upgrades, bsd-mailx, nftables, ufw, fail2ban, wireguard, qrencode, rclone, ddclient, zip, unzip.<br>
Required additional software: Pi-Hole.<br>
PC used for programming client-side uses Linux OS.


### 1. – Installing Raspberry Pi OS on a microSD memory card.
<a href="https://www.raspberrypi.com/software/" target="_blank">Raspberry Pi Imager software</a> for your preferred OS can be downloaded from Raspberry official website.<br>
Choose your <abbr title="Raspberry PI">RPI</abbr> model, the desired version of Raspberry Pi OS and the microSD card of destination.<br>
After clicking NEXT button, edit the configuration and enable <abbr title="Secure Shell">SSH</abbr> service otherwise you will not have access to the <abbr title="Raspberry PI">RPI</abbr> if you have chosen an headless OS; change the default <var>userID</var> (pi), set an access secure password, locales and keyboard configuration; also setup SSID name, access credentials and country in case you want to connect to the <abbr title="Raspberry PI">RPI</abbr> via Wi-Fi.<br>
The imager will format your microSD card and install selected OS; a message will pop-up after the procedure is finished, telling to remove the microSD card from the reader.


### 2. – First access to RPI.
Insert the microSD card and power up the RPI.<br>
To access the RPI via SSH you need to provide <var>userID</var>, RPI IP address or localhost name and password in a command via terminal that follow this syntax:
```bash
ssh userID@192.168.XXX.XXX
```
You can discover the IP address assigned by router’s DHCP to the RPI by accessing to your router web-admin page or running this command on your Linux client:
```bash
ip neigh show
```
or running this other command if you have nmap installed, adjusting the sub-net according to your LAN settings:
```bash
nmap -sP 192.168.XXX.0/24
```
NOTE: following this guide you will set a static IP through the RPI configuration, but is always a good practice to reserve a specific static IP address in router’s configuration: it will link the RPI connected device’s MAC address to the specified LAN IP address. It should be done for all the clients that will use the RPI for a better control over your network. You can also adjust the DHCP range of your router.<br>
Once access is gained with password set in imager configuration, execute:
```bash
sudo raspi-config
```
an interactive menu will pop-up, choose “Advanced Settings” (last option on the list) and “Expand File System”.<br>
You can navigate menu with ARROW keys, TAB key and confirm with ENTER key.<br>
Exit the menu and the RPI will reboot to expand the file system to the whole microSD card.<br>
The connection via SSH from your client terminal to the RPI will be terminated, obviously.

### 3. – Set a static IP address on the RPI.
After rebooting, access again the RPI via SSH and update the RPI executing:
```bash
sudo apt update && sudo apt upgrade -y
```
It will take some time, depending on the amount of the upgrades needed by the system, your internet connection speed and the RPI model performance.<br>
After upgrade process has finished, execute this command:
```bash
sudo nmtui
```
from the interactive menu that will show up you will be able to select the connection device you’re using (ethernet or Wi-Fi) and set up a static IP address, gateway and DNS server(s) address(es). If, as suggested, you reserved a static IP address on the router, be sure that the IP address set is the same.<br>
Reboot the RPI and all configuration changes will take effect:
```bash
sudo reboot
```

### 4. – Set SSH access to the RPI using a security token.
Security key token implements strong security standards to SSH access to your RPI and along with failtoban and ufw that will be configured later prevent access through brute-force attacks on your RPI SSH port; for this purpose you can also change the default port (22) used by SSH protocol.   
First you need to generate the security key token on your Linux client PC:
```bash
ssh-keygen -t rsa
```
you will be asked to give a name to generated security key token;   
both public and private key will be stored in /home/*client_userID*/.ssh/ directory of your Linux client PC;   
copy the token public key to the RPI, adjusting *tokenname*, *RPI_static_IP* and *>userID* varibles according to your settings:
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
