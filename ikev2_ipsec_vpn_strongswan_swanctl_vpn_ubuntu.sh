#!/bin/bash

# CHECK IF THE REQUIRED PARAMETERS ARE PROVIDED
if [ $# -ne 2 ]; then
    echo "Usage: $0 VPN_USER_NAME VPN_USER_PASSWORD [INTERFACE]"
    exit 1
fi

# UPDATE THE SYSTEM
echo "Updating the system..."
apt update

# INSTALL NECESSARY PACKAGES
echo "Installing necessary packages..."
export DEBIAN_FRONTEND=noninteractive
apt -y install strongswan-swanctl strongswan-pki charon-systemd libcharon-extra-plugins \
  libcharon-extauth-plugins iptables-persistent uuid-runtime curl libtss2-tcti-tabrmd0 iproute2

# ASSIGNING USER INPUTS TO VARIABLES
VPN_USER_NAME=$1
VPN_USER_PASSWORD=$2

if [[ -n "$3" ]]; then
    INTERFACE=$3
else
    INTERFACE=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")
fi 

# GENERATE A SHARED KEY AND GET THE PUBLIC IP ADDRESS
SHARED_KEY=$(uuidgen)
IP=$(curl -s api.ipify.org)

cat << EOF

-----------------------------------------------------------
    Your INTERFACE: ${INTERFACE}
-----------------------------------------------------------
-----------------------------------------------------------
    Your shared key (PSK): ${SHARED_KEY}
-----------------------------------------------------------
-----------------------------------------------------------
    Your IP: ${IP}
-----------------------------------------------------------

EOF
echo -e "Press Enter to continue...\n"
read -r

# ====================
# CREATE CERTIFICATES
# ====================
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
echo "Copying certificates to the required directories..."
cp ~/pki/ca-cert.pem /etc/swanctl/x509ca/
cp ~/pki/server-cert.pem /etc/swanctl/x509/
cp ~/pki/server-key.pem /etc/swanctl/private/

# ====================
# CONFIGURE STRONGSWAN
# ====================
echo "Configuring StrongSwan..."
PROPOSALS="chacha20poly1305-sha512-curve25519-prfsha512,aes256gcm16-sha384-prfsha384-ecp384,aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024,aes256-sha256-modp2048"
ESP_PROPOSALS="chacha20poly1305-sha512,aes256gcm16-ecp384,aes256-sha256,aes256-sha1,3des-sha1"
ADDRESSES_POOL="10.10.10.0/24"

# CREATE SWANCTL CONFIGURATION
cat <<EOF | tee /etc/swanctl/swanctl.conf
connections {
  rsa {
    proposals = ${PROPOSALS}
    pools = rw_pool
    local {
      auth = pubkey
      certs = server-cert.pem
      id = ${IP}
    }
    remote {
      auth = eap-mschapv2
      eap_id = %any
    }
    children {
      rw {
        local_ts = 0.0.0.0/0
        remote_ts = ${ADDRESSES_POOL}
        esp_proposals = ${ESP_PROPOSALS}
      }
    }
    mobike = yes
    send_certreq = no
  }

  psk {
    proposals = ${PROPOSALS}
    pools = rw_pool
    local {
      auth = psk
      id = ${IP}
    }
    remote {
      auth = psk
    }
    children {
      rw {
        local_ts = 0.0.0.0/0
        remote_ts = ${ADDRESSES_POOL}
        esp_proposals = ${ESP_PROPOSALS}
      }
    }

    mobike = yes
    send_certreq = no
  }
}

secrets {
  eap-carol {
    id = ${VPN_USER_NAME}
    secret = ${VPN_USER_PASSWORD}
  }
  ike-carol {
    secret = ${SHARED_KEY}
  }
}

pools {
  rw_pool {
    addrs = ${ADDRESSES_POOL}
  }
}
EOF

# ===========================
# SETUP IPTABLES AND FIREWALL
# ===========================
echo "Setting up iptables and firewall..."
# Disable UFW and reset iptables rules
ufw disable
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -F
iptables -Z

# RULES FOR SSH
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# RULES FOR LOOPBACK
iptables -A INPUT -i lo -j ACCEPT

# RULES FOR IPSEC
iptables -A INPUT -p udp --dport 500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT

# RULES FOR FORWARDING TRAFFIC
iptables -A FORWARD --match policy --pol ipsec --dir in --proto esp -s ${ADDRESSES_POOL} -j ACCEPT
iptables -A FORWARD --match policy --pol ipsec --dir out --proto esp -d ${ADDRESSES_POOL} -j ACCEPT
iptables -t nat -A POSTROUTING -s ${ADDRESSES_POOL} -o $INTERFACE -m policy --pol ipsec --dir out -j ACCEPT
iptables -t nat -A POSTROUTING -s ${ADDRESSES_POOL} -o $INTERFACE -j MASQUERADE
iptables -t mangle -A FORWARD --match policy --pol ipsec --dir in -s ${ADDRESSES_POOL} -o $INTERFACE -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360

# BLOCK ALL OTHER TRAFFIC
iptables -A INPUT -j DROP
iptables -A FORWARD -j DROP

# SAVE IPTABLES RULES
echo "Saving iptables rules..."
netfilter-persistent save
netfilter-persistent reload

# =================
# CHANGES TO SYSCTL
# =================
echo "Applying sysctl changes..."
sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/" /etc/sysctl.conf
sed -i "s/#net.ipv4.conf.all.accept_redirects = 0/net.ipv4.conf.all.accept_redirects = 0/" /etc/sysctl.conf
sed -i "s/#net.ipv4.conf.all.send_redirects = 0/net.ipv4.conf.all.send_redirects = 0/" /etc/sysctl.conf
echo "net.ipv4.ip_no_pmtu_disc = 1" | tee -a /etc/sysctl

# ===================================================
# RESTART STRONGSWAN SERVICE AND LOAD SWANCTL CONFIGS
# ===================================================
echo "Restarting StrongSwan..."
systemctl restart strongswan
echo "Applying Strongswan configuration..."
swanctl --load-all

# ====================================
# SHOW CA-CERT.PEM
# ====================================
cat << EOF
-----------------------------------------------------------
                  Your ca-cert.pem
-----------------------------------------------------------

EOF
cat /etc/swanctl/x509ca/ca-cert.pem

# ==============================================
# ASK THE USER IF THEY WANT TO REBOOT THE SYSTEM
# ==============================================
echo ""
echo "The system must be rebooted for the changes to take effect."
read -p "Do you want to reboot the system now? (y/n): " REBOOT_CHOICE

if [[ "$REBOOT_CHOICE" == "y" || "$REBOOT_CHOICE" == "Y" ]]; then
    echo "Rebooting the system..."
    reboot
else
    echo "The system must be rebooted later for the changes to take effect."
fi
