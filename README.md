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
Hardware used is a <abbr title="Raspberry PI">RPI</abbr> 4 4Gb RAM with a 64Gb microSD memory card, cable connected to my 5G modem/router <abbr title="Local Area Network">LAN</abbr> port, but it can be set to use Wi-Fi connection instead. It will also works on RPI 3 models. You’ll also need a microSD card reader.
The operative system installed on the <abbr title="Raspberry PI">RPI</abbr> is Raspberry Pi OS 64bit headless (without desktop environment), based on Linux Debian Bookworm.
Required additional Linux software packages from APT: unattended-upgrades, bsd-mailx, nftables, ufw, fail2ban, wireguard, qrencode, rclone, ddclient, zip, unzip.
Required additional software: Pi-Hole.
PC used for programming client-side uses Linux OS.


### 1. – Installing Raspberry Pi OS on a microSD memory card.
Raspberry Pi Imager software for your preferred OS can be downloaded from Raspberry official website.
Choose your <abbr title="Raspberry PI">RPI</abbr> model, the desired version of Raspberry Pi OS and the microSD card of destination.
After clicking NEXT button, edit the configuration and enable <abbr title="Secure Shell">SSH</abbr> service otherwise you will not have access to the <abbr title="Raspberry PI">RPI</abbr> if you have chosen an headless OS; change the default <var>userID</var> (pi), set an access secure password, locales and keyboard configuration; also setup SSID name, access credentials and country in case you want to connect to the <abbr title="Raspberry PI">RPI</abbr> via Wi-Fi.
The imager will format your microSD card and install selected OS; a message will pop-up after the procedure is finished, telling to remove the microSD card from the reader.


### 2. – First access to RPI.

```bash
sudo apt update && sudo apt upgrade
```
