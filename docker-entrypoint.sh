#!/bin/sh

if [ ! -f /etc/ocserv/certs/server-key.pem ] || [ ! -f /etc/ocserv/certs/server-cert.pem ]; then
	# Check environment variables
	# MY_VAR=${MY_VAR:-"DefaultValue"}

	AUTH=${AUTH:-"plain"}
	CA_CN=${CA_CN:-"BigCorp Server CA"}
	CA_ORG=${CA_ORG:-"BigCorp"}
	CA_DAYS=${CA_DAYS:-1825}
	SRV_CN=${SRV_CN:-"www.example.com"}
	SRV_ORG=${SRV_ORG:-"MyCompany"}
	SRV_DAYS=${SRV_DAYS:-1825}
	

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

if [ "${AUTH}" = "plain" ]; then

	export AUTH="plain[passwd=/etc/ocserv/ocpasswd]"
	export CERT_USER_OID="0.9.2342.19200300.100.1.1"

	if [ ! -z "$USER_NAME" ]  && [ ! -f /etc/ocserv/ocpasswd ]; then
	# Create a user
	echo "Create user ${USER_NAME} with password 'test'"
	echo "$USER_NAME:*:\$5\$DktJBFKobxCFd7wN\$sn.bVw8ytyAaNamO.CvgBvkzDiFR6DaHdUzcif52KK7" > /etc/ocserv/ocpasswd
	fi

elif [ "${AUTH}" = "cert" ]; then
	
	export AUTH="certificate"
	export CERT_USER_OID="2.5.4.3"

	if [ ! -z "$USER_NAME" ]; then

		CLIENT_CN=${CLIENT_CN:-${USER_NAME}}
  
		# Generate user certificate
		occert ${CLIENT_CN} ${CLIENT_DAYS} test

	fi

fi

# Set rest of variables

export TCP_PORT=${TCP_PORT:-443}
export UDP_PORT=${UDP_PORT:-443}
export ISOLATE_WORKERS=${ISOLATE_WORKERS:-true}
export MAX_CLIENTS=${MAX_CLIENTS:-16}
export MAX_SAME_CLIENTS=${MAX_SAME_CLIENTS:-2}
export RATE_LIMIT=${RATE_LIMIT:-100}
export SERVER_STATS_RESET=${SERVER_STATS_RESET:-604800}
export KEEPALIVE=${KEEPALIVE:-32400}
export DPD=${DPD:-90}
export MOBILE_DPD=${MOBILE_DPD:-1800}
export SWITCH_TO_TCP=${SWITCH_TO_TCP:-25}
export MTU_DISCOVERY=${MTU_DISCOVERY:-false}
export COMPRESSION=${COMPRESSION:-false}
# TLS PRIO OPTIONS
# //does't work// "NORMAL:%SERVER_PRECEDENCE:%COMPAT:-VERS-SSL3.0:-VERS-TLS1.0:-VERS-TLS1.1:-CIPHER-ALL:+CIPHER-CHACHA20-POLY1305:+CIPHER-AES256-GCM:+CIPHER-ECDHE-RSA-AES128-GCM-SHA256:+CIPHER-ECDHE-RSA-AES256-GCM-SHA384"
# "NORMAL:%SERVER_PRECEDENCE:-VERS-SSL3.0:-VERS-TLS1.0:-VERS-TLS1.1:-CIPHER-ALL:+AES-256-GCM:+CHACHA20-POLY1305:+ECDHE-RSA"
export TLS_PRIORITIES=${TLS_PRIORITIES:-"NORMAL:%SERVER_PRECEDENCE:%COMPAT:-VERS-SSL3.0:-VERS-TLS1.0:-VERS-TLS1.1"}
export AUTH_TIMEOUT=${AUTH_TIMEOUT:-240}
export MIN_REAUTH_TIME=${MIN_REAUTH_TIME:-300}
export MAX_BAN_SCORE=${MAX_BAN_SCORE:-80}
export BAN_RESET_TIME=${BAN_RESET_TIME:-1200}
export COOKIE_TIMEOUT=${COOKIE_TIMEOUT:-300}
export DENY_ROAMING=${DENY_ROAMING:-false}
export REKEY_TIME=${REKEY_TIME:-172800}
export USE_OCCTL=${USE_OCCTL:-true}
export LOG_LEVEL=${LOG_LEVEL:-2}
export DEV_NAME=${DEV_NAME:-vpns}
export PREDICTABLE_IPS=${PREDICTABLE_IPS:-true}
export DEFAULT_DOMAIN=${DEFAULT_DOMAIN:-"example.com"}
export IPV4_NETWORK=${IPV4_NETWORK:-"192.168.99.0"}
export IPV4_NETMASK=${IPV4_NETMASK:-"255.255.255.0"}
export IPV4_DNS=${IPV4_DNS:-"8.8.8.8"}
export PING_LEASES=${PING_LEASES:-false}
export CISCO_CLIENT_COMPAT=${CISCO_CLIENT_COMPAT:-true}
export DTLS_LEGACY=${DTLS_LEGACY:-true}
export CISCO_SVC_CLIENT_COMPAT=${CISCO_SVC_CLIENT_COMPAT:-false}
export CLIENT_BYPASS_PROTO=${CLIENT_BYPASS_PROTO:-false}
export CAMOUFLAGE=${CAMOUFLAGE:-false}
export CAMOUFLAGE_SECRET=${CAMOUFLAGE_SECRET:-"mysecretkey"}
export CAMOUFLAGE_REALM=${CAMOUFLAGE_REALM:-"Restricted Content"}


# Open ipv4 ip forward
# sysctl -w net.ipv4.ip_forward=1

# Enable NAT forwarding
iptables -t nat -A POSTROUTING -j MASQUERADE -s "${IPV4_NETWORK}"/"${IPV4_NETMASK}"
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Enable TUN device
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

# Append routes
cat /tmp/routes.txt >> /tmp/ocserv.conf

# Update config
echo "Creating ocserv config '/etc/ocserv/ocserv.conf'"
envsubst < /tmp/ocserv.conf > /etc/ocserv/ocserv.conf



# Run OpennConnect Server
exec "$@"
