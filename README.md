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

```bash
sudo apt update && sudo apt upgrade
```
