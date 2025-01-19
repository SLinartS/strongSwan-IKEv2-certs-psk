#!/bin/bash

# CHECK IF THE REQUIRED PARAMETERS ARE PROVIDED
if [ $# -ne 3 ]; then
    echo "Usage: $0 INTERFACE VPN_USER_NAME VPN_USER_PASSWORD"
    exit 1
fi

# ASSIGNING USER INPUTS TO VARIABLES
INTERFACE=$1
VPN_USER_NAME=$2
VPN_USER_PASSWORD=$3

# GENERATE A SHARED KEY AND GET THE PUBLIC IP ADDRESS
SHARED_KEY=$(uuidgen)
IP=$(curl -s api.ipify.org)

echo "Your shared key (PSK) - $SHARED_KEY, your IP - $IP"
echo -e "Press Enter to continue...\n"
read -r

# UPDATE THE SYSTEM
echo "Updating the system..."
sudo apt update
sudo apt -y upgrade
sudo apt -y dist-upgrade

# INSTALL NECESSARY PACKAGES
echo "Installing necessary packages..."
export DEBIAN_FRONTEND=noninteractive
sudo apt -y install strongswan strongswan-pki libcharon-extra-plugins libcharon-extauth-plugins iptables-persistent libtss2-tcti-tabrmd0

# ===================
# CREATE CERTIFICATES
# ===================
echo "Creating certificates..."
mkdir -p ~/pki
chmod 700 ~/pki

# GENERATE CA AND SERVER KEYS AND CERTIFICATES
pki --gen --type ed25519 --outform pem >~/pki/ca-key.pem
pki --self --ca --lifetime 3652 --in ~/pki/ca-key.pem --dn "CN=${IP}" --outform pem >~/pki/ca-cert.pem

pki --gen --type ed25519 --outform pem >~/pki/server-key.pem
pki --req --type priv --in ~/pki/server-key.pem --dn "CN=${IP}" --san @${IP} --san ${IP} --outform pem >~/pki/server-req.pem

pki --issue --cacert ~/pki/ca-cert.pem --cakey ~/pki/ca-key.pem --type pkcs10 \
    --in ~/pki/server-req.pem --serial 01 --lifetime 1826 --outform pem --flag serverAuth >~/pki/server-cert.pem

# COPY CERTIFICATES TO THE REQUIRED DIRECTORIES
sudo cp ~/pki/ca-key.pem /etc/ipsec.d/private/
sudo cp ~/pki/server-key.pem /etc/ipsec.d/private/
sudo cp ~/pki/ca-cert.pem /etc/ipsec.d/cacerts/
sudo cp ~/pki/server-cert.pem /etc/ipsec.d/certs/
sudo cp ~/pki/server-req.pem /etc/ipsec.d/reqs/

# ==================
# STRONG SWAN CONFIG
# ==================
echo "Configuring StrongSwan..."
PROPOSALS="chacha20poly1305-sha512-curve25519-prfsha512,aes256gcm16-sha384-prfsha384-ecp384,aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024,aes256-sha256-modp2048"
ESP_PROPOSALS="chacha20poly1305-sha512,aes256gcm16-ecp384,aes256-sha256,aes256-sha1,3des-sha1"
ADDRESSES_POOL="10.10.10.0/24"

# CREATE IPSEC CONFIGURATION
cat <<EOF | sudo tee /etc/ipsec.conf
config setup
    charondebug="all"
    uniqueids=yes

conn psk
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
    ike=${PROPOSALS}!
    esp=${ESP_PROPOSALS}!
    dpdaction=restart
    dpddelay=300s
    rekey=no
    left=%any
    leftid=%any
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightdns=8.8.8.8,8.8.4.4
    rightsourceip=${ADDRESSES_POOL}
    authby=secret

conn rsa
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
    dpdaction=restart
    dpddelay=300s
    rekey=no
    left=%any
    leftid=${IP}
    leftcert=server-cert.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=${ADDRESSES_POOL}
    rightdns=8.8.8.8,8.8.4.4
    rightsendcert=never
    eap_identity=%identity
    ike=${PROPOSALS}!
    esp=${ESP_PROPOSALS}!
EOF

# ADD SECRETS TO IPSEC.SECRETS
cat <<EOF | sudo tee /etc/ipsec.secrets
: RSA "server-key.pem"
${VPN_USER_NAME} : EAP "${VPN_USER_PASSWORD}"

: PSK $SHARED_KEY
EOF

# ===========================
# SETUP IPTABLES AND FIREWALL
# ===========================
echo "Setting up iptables and firewall..."
# Disable UFW and reset iptables rules
ufw disable
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -F
sudo iptables -Z

# RULES FOR SSH
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# RULES FOR LOOPBACK
sudo iptables -A INPUT -i lo -j ACCEPT

# RULES FOR IPSEC
sudo iptables -A INPUT -p udp --dport 500 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 4500 -j ACCEPT

# RULES FOR FORWARDING TRAFFIC
sudo iptables -A FORWARD --match policy --pol ipsec --dir in --proto esp -s ${ADDRESSES_POOL} -j ACCEPT
sudo iptables -A FORWARD --match policy --pol ipsec --dir out --proto esp -d ${ADDRESSES_POOL} -j ACCEPT
sudo iptables -t nat -A POSTROUTING -s ${ADDRESSES_POOL} -o $INTERFACE -m policy --pol ipsec --dir out -j ACCEPT
sudo iptables -t nat -A POSTROUTING -s ${ADDRESSES_POOL} -o $INTERFACE -j MASQUERADE
sudo iptables -t mangle -A FORWARD --match policy --pol ipsec --dir in -s ${ADDRESSES_POOL} -o $INTERFACE -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360

# BLOCK ALL OTHER TRAFFIC
sudo iptables -A INPUT -j DROP
sudo iptables -A FORWARD -j DROP

# SAVE IPTABLES RULES
echo "Saving iptables rules..."
sudo netfilter-persistent save
sudo netfilter-persistent reload

# =================
# CHANGES TO SYSCTL
# =================
echo "Applying sysctl changes..."
sudo sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/" /etc/sysctl.conf
sudo sed -i "s/#net.ipv4.conf.all.accept_redirects = 0/net.ipv4.conf.all.accept_redirects = 0/" /etc/sysctl.conf
sudo sed -i "s/#net.ipv4.conf.all.send_redirects = 0/net.ipv4.conf.all.send_redirects = 0/" /etc/sysctl.conf
echo "net.ipv4.ip_no_pmtu_disc = 1" | sudo tee -a /etc/sysctl

# =====================================
# RESTART STRONGSWAN AND IPSEC SERVICES
# =====================================
echo "Restarting ipsec..."
sudo ipsec restart
echo "Restarting StrongSwan..."
sudo systemctl restart strongswan-starter

# ====================================
# SHOW CA-CERT.PEM
# ====================================
echo "Your ca-cert.pem"
echo ""
cat /etc/ipsec.d/cacerts/ca-cert.pem

# ==============================================
# ASK THE USER IF THEY WANT TO REBOOT THE SYSTEM
# ==============================================
echo ""
echo "The system must be rebooted for the changes to take effect."
read -p "Do you want to reboot the system now? (y/n): " REBOOT_CHOICE

if [[ "$REBOOT_CHOICE" == "y" || "$REBOOT_CHOICE" == "Y" ]]; then
    echo "Rebooting the system..."
    sudo reboot
else
    echo "The system must be rebooted later for the changes to take effect."
fi
