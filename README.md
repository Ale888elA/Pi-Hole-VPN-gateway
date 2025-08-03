<div align="center">## Using a Raspberry Pi as a VPN server, Gateway and DNS sinkhole</div>
This guide is suited for the security exigences of a home network and for private use; in a business environment, especially if you deal with customer’s sensible data, is strongly advised to use a professional device that uses pfsense firewall software and strong VPN encryption; NetGate for instance offers a wide variety of devices and cloud solutions that fit security exigences and traffic loads from remote working and small business to large offices, corporate business and data centers.

### Main goals:
<ul>
        <li>install and configure on the [Raspberry PI](https://www.raspberrypi.com/) (<abbr title="Raspberry PI">RPI</abbr>) a [VPN](https://en.wikipedia.org/wiki/Virtual_private_network) server using [Wireguard](https://www.wireguard.com/) protocol;</li>
        <li>install and configure on the <abbr title="Raspberry PI">RPI</abbr> a network-wide [DNS](https://en.wikipedia.org/wiki/Domain_Name_System) sinkhole for blocking ads, tracking, scam, malware and phishing known referrals using [Pi Hole](https://pi-hole.net/);</li>
        <li>configure the <abbr title="Raspberry PI">RPI</abbr> to be used as gateway, to block [IPv6](https://en.wikipedia.org/wiki/IPv6) traffic for security purposes and hijack hard-coded <abbr title="Domain Name System">DNS</abbr> providers on Smart-TVs.</li>
</ul>


```bash
sudo apt update && sudo apt upgrade
```
