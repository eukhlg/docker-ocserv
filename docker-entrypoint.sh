#!/bin/sh

if [ ! -f /etc/ocserv/certs/server-key.pem ] || [ ! -f /etc/ocserv/certs/server-cert.pem ]; then
	# Check environment variables
	if [ -z "$AUTH" ]; then
		AUTH="plain"
	fi
	
	if [ -z "$CA_CN" ]; then
		CA_CN="VPN CA"
	fi

	if [ -z "$CA_ORG" ]; then
		CA_ORG="Big Corp"
	fi

	if [ -z "$CA_DAYS" ]; then
		CA_DAYS=9999
	fi

	if [ -z "$SRV_CN" ]; then
		SRV_CN="www.example.com"
	fi

	if [ -z "$SRV_ORG" ]; then
		SRV_ORG="MyCompany"
	fi

	if [ -z "$SRV_DAYS" ]; then
		SRV_DAYS=9999
	fi
	

	# No certification found, generate one
	mkdir /etc/ocserv/certs
	cd /etc/ocserv/certs
	certtool --generate-privkey --outfile ca-key.pem
	cat > ca.tmpl <<-EOCA
	cn = "$CA_CN"
	organization = "$CA_ORG"
	serial = 1
	expiration_days = $CA_DAYS
	ca
	signing_key
	cert_signing_key
	crl_signing_key
	EOCA
	certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca.pem
	certtool --generate-privkey --outfile server-key.pem 
	cat > server.tmpl <<-EOSRV
	cn = "$SRV_CN"
	organization = "$SRV_ORG"
	expiration_days = $SRV_DAYS
	signing_key
	encryption_key
	tls_www_server
	EOSRV
	certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server-cert.pem
fi

if [ "${AUTH}" = "plain" ] && [ ! -f /etc/ocserv/ocpasswd ]; then

	export AUTH="plain[passwd=/etc/ocserv/ocpasswd]"
	export CERT_USER_OID="0.9.2342.19200300.100.1.1"

	if [ ! -z "$TEST_USER" ]; then
	# Create a user
	echo "Create user ${TEST_USER} with password 'test'"
	echo "$TEST_USER:*:\$5\$DktJBFKobxCFd7wN\$sn.bVw8ytyAaNamO.CvgBvkzDiFR6DaHdUzcif52KK7" > /etc/ocserv/ocpasswd
	fi

fi

if [ "${AUTH}" = "cert" ]; then
	
	export AUTH="certificate"
	export CERT_USER_OID="2.5.4.3"

	if [ ! -z "$TEST_USER" ]; then

		if [ -z "$CLIENT_CN" ]; then
			CLIENT_CN=${TEST_USER}
		fi
		
		if [ -z "$CLIENT_DAYS" ]; then
			CLIENT_DAYS=365
		fi

		if [ ! -f /etc/ocserv/certs/client/${CLIENT_CN}-key.pem ] || [ ! -f /etc/ocserv/certs/client/${$CLIENT_CN}.pem ]; then
			# Generate user certificate
			occert ${CLIENT_CN} ${CLIENT_DAYS} test
		fi

	fi

fi

# Set network and DNS for VPN clients if not set

if [ -z "$IPV4_NETWORK" ]; then
	export IPV4_NETWORK="192.168.99.0"
fi

if [ -z "$IPV4_NETWORK" ]; then
	export IPV4_NETMASK="255.255.255.0"
fi

if [ -z "$IPV4_DNS" ]; then
	export IPV4_DNS="8.8.8.8"
fi

# Open ipv4 ip forward
# sysctl -w net.ipv4.ip_forward=1

# Enable NAT forwarding
iptables -t nat -A POSTROUTING -j MASQUERADE -s "${IPV4_NETWORK}"/"${IPV4_NETMASK}"
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Enable TUN device
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

# Update config
if [ ! -f /etc/ocserv/ocserv.conf ]; then
	echo "Creating ocserv config '/etc/ocserv/ocserv.conf'"
	envsubst < /tmp/ocserv.conf > /etc/ocserv/ocserv.conf
fi

# Run OpennConnect Server
exec "$@"
