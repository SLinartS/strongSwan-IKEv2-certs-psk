# StrongSwan IKEv2/IPsec VPN setup

## [RU](https://github.com/SLinartS/strongSwan-IKEv2-certs-psk/blob/main/README.ru.md)

## Overview
This repository contains a couple of scripts that you can use to deploy your IKEv2/IPsec VPN server using certificates or PSK key using [Strongswan](https://github.com/strongswan/strongswan). StrongSwan is an open-source IPsec-based VPN solution that allows secure communication over the internet.

I've spent a lot of time researching information about connecting using swanctl.conf, as there are very few ready-made guides for the new version of the config. I hope this will help someone.

## Contributing
The scripts aren't perfect, I don't write in bash very often. Feel free to fork the repository, make changes, and submit fix requests

## Based on
 - [Digital Ocean tutorial for Ubuntu-16-04](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-ikev2-vpn-server-with-strongswan-on-ubuntu-16-04)
 - [Strongswan official documentation](https://docs.strongswan.org/docs/latest/index.html)
 - [The repository from which I built my script for the old config version (thanks!)](https://github.com/truemetal/ikev2_vpn/tree/master)

### Deploy with certs (+ username/password auth) and Pre Shared Key (PSK) / 

This script generates a PSK and print it to the console, where you can copy and press enter to continue.

Client-side certificate validation is disabled, which may be less secure, but the connection becomes easier. You only need a Certificate Authority (ca-cert.pem) certificate on the client device to connect.

After connecting to your server via ssh, simply run this command (before doing so, change the values of `{your_server_default_eth_interface}` `{vpn_user_name}` `{vpn_user_password}` to your own):
#### for new (/etc/swanctl/swanctl.conf) configuring: 
```BASH
curl -L https://raw.githubusercontent.com/SLinartS/strongswan-vpn-IKEv2-certs-psk/main/ikev2_ipsec_vpn_strongswan_swanctl_vpn_ubuntu.sh -o ~/deploy.sh && sudo chmod +x ~/deploy.sh && sudo ~/deploy.sh {your_server_default_eth_interface} {vpn_user_name} {vpn_user_password}
```

#### or for old (/etc/ipsec.conf) configuring: 
```BASH
curl -L https://raw.githubusercontent.com/SLinartS/strongswan-vpn-IKEv2-certs-psk/main/ikev2_ipsec_vpn_strongswan_ipsecconf_vpn_ubuntu.sh -o ~/deploy.sh && sudo chmod +x ~/deploy.sh && sudo ~/deploy.sh {your_server_default_eth_interface} {vpn_user_name} {vpn_user_password}
```

### Example 
```BASH
curl -L https://raw.githubusercontent.com/SLinartS/strongswan-vpn-IKEv2-certs-psk/main/ikev2_ipsec_vpn_strongswan_swanctl_vpn_ubuntu.sh -o ~/deploy.sh && sudo chmod +x ~/deploy.sh && sudo ~/deploy.sh enp4s0 SharlizUser SharlizQwerty123
```

### Connecting
The script makes it possible to connect using both certificates and Pre Shared Key (PSK).
The settings may be different on each system, search the internet to find it.

#### Certificates:
You will need 
- contents of `ca-cert.pem` (printed before prompting to reboot the device)
- `{vpn_user_name}` and `{vpn_user_password}` that you entered when running the script.
- gateway ip (public static ip address of your server)

#### PSK:
- PSK (printed at the very beginning of the script execution)
- gateway ip (public static ip address of your server)