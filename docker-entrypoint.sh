#!/bin/sh
set -e  # Exit on error

validate_env_vars() {
  for var in AUTH CA_CN CA_ORG CA_DAYS SRV_CN SRV_ORG SRV_DAYS; do
    if [ -z "$(eval echo \$$var)" ]; then
      echo "Error: Environment variable $var is not set."
      exit 1
    fi
  done
}

generate_certificates() {
  mkdir -p /etc/ocserv/certs
  cd /etc/ocserv/certs

  # Generate CA
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

  # Generate Server Certificate
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
}

create_user_plain() {
  if [ ! -z "$USER_NAME" ] && [ ! -f /etc/ocserv/ocpasswd ]; then
    echo "Create user ${USER_NAME} with password 'test'"
    echo "$USER_NAME:*:\$5\$DktJBFKobxCFd7wN\$sn.bVw8ytyAaNamO.CvgBvkzDiFR6DaHdUzcif52KK7" > /etc/ocserv/ocpasswd
  fi
}

create_user_cert() {
  if [ ! -z "$USER_NAME" ]; then
    echo "Create user ${USER_NAME} with password 'test'"
    occert ${USER_NAME} ${CLIENT_DAYS} test
  fi
}


set_defaults() {
  AUTH=${AUTH:-"plain"}
  CA_CN=${CA_CN:-"BigCorp Server CA"}
  CA_ORG=${CA_ORG:-"BigCorp"}
  CA_DAYS=${CA_DAYS:-1825}
  SRV_CN=${SRV_CN:-"www.example.com"}
  SRV_ORG=${SRV_ORG:-"MyCompany"}
  SRV_DAYS=${SRV_DAYS:-1825}
  TCP_PORT=${TCP_PORT:-443}
  UDP_PORT=${UDP_PORT:-443}
  ROUTE=${ROUTE:-"default"}
  NO_ROUTE=${NO_ROUTE:-"192.168.0.0/16; 10.0.0.0/8; 172.16.0.0/12"}
  ISOLATE_WORKERS=${ISOLATE_WORKERS:-true}
  MAX_CLIENTS=${MAX_CLIENTS:-16}
  MAX_SAME_CLIENTS=${MAX_SAME_CLIENTS:-2}
  RATE_LIMIT=${RATE_LIMIT:-100}
  SERVER_STATS_RESET=${SERVER_STATS_RESET:-604800}
  KEEPALIVE=${KEEPALIVE:-32400}
  DPD=${DPD:-90}
  MOBILE_DPD=${MOBILE_DPD:-1800}
  SWITCH_TO_TCP=${SWITCH_TO_TCP:-25}
  MTU_DISCOVERY=${MTU_DISCOVERY:-false}
  COMPRESSION=${COMPRESSION:-false}
  TLS_PRIORITIES=${TLS_PRIORITIES:-"NORMAL:%SERVER_PRECEDENCE:%COMPAT:-VERS-SSL3.0:-VERS-TLS1.0:-VERS-TLS1.1"}
  AUTH_TIMEOUT=${AUTH_TIMEOUT:-240}
  MIN_REAUTH_TIME=${MIN_REAUTH_TIME:-300}
  MAX_BAN_SCORE=${MAX_BAN_SCORE:-80}
  BAN_RESET_TIME=${BAN_RESET_TIME:-1200}
  COOKIE_TIMEOUT=${COOKIE_TIMEOUT:-300}
  DENY_ROAMING=${DENY_ROAMING:-false}
  REKEY_TIME=${REKEY_TIME:-172800}
  USE_OCCTL=${USE_OCCTL:-true}
  LOG_LEVEL=${LOG_LEVEL:-2}
  DEV_NAME=${DEV_NAME:-vpns}
  PREDICTABLE_IPS=${PREDICTABLE_IPS:-true}
  DEFAULT_DOMAIN=${DEFAULT_DOMAIN:-"example.com"}
  IPV4_NETWORK=${IPV4_NETWORK:-"192.168.99.0"}
  IPV4_NETMASK=${IPV4_NETMASK:-"255.255.255.0"}
  IPV4_DNS=${IPV4_DNS:-"8.8.8.8"}
  PING_LEASES=${PING_LEASES:-false}
  MTU=${MTU:-1420}
  CISCO_CLIENT_COMPAT=${CISCO_CLIENT_COMPAT:-true}
  DTLS_LEGACY=${DTLS_LEGACY:-true}
  CISCO_SVC_CLIENT_COMPAT=${CISCO_SVC_CLIENT_COMPAT:-false}
  CLIENT_BYPASS_PROTO=${CLIENT_BYPASS_PROTO:-false}
  CAMOUFLAGE=${CAMOUFLAGE:-false}
  CAMOUFLAGE_SECRET=${CAMOUFLAGE_SECRET:-"mysecretkey"}
  CAMOUFLAGE_REALM=${CAMOUFLAGE_REALM:-"Restricted Content"}
}

setup_network() {
  iptables -t nat -A POSTROUTING -j MASQUERADE -s "${IPV4_NETWORK}"/"${IPV4_NETMASK}"
  iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200
  chmod 600 /dev/net/tun
}

update_config() {

 # Setup configuration
    # Do we really need in with docker?
    # -e "s/\(^tcp-port = \)[0-9]\+/\1${TCP_PORT}/" \
    # -e "s/\(^udp-port = \)[0-9]\+/\1${UDP_PORT}/" \

    # Settings for ocserv user
    # -e "s/\(^run-as-group = \).*/\1ocserv/" \
    # -e "s/\(^socket-file = \).*/\1\/var\/run\/ocserv\/ocserv-socket/" \

  sed -e "s/\(^auth = \).*/\1${AUTH_STRING}/" \
      -e "s/\.\/sample\.passwd/\/etc\/ocserv\/ocpasswd/" \
      -e "s/\(^run-as-user = \).*/\1root/" \
      -e "s/\.\.\/tests/\/etc\/ocserv/" \
      -e "s/\(^isolate-workers = \)true/\1${ISOLATE_WORKERS}/" \
      -e "s/\(^max-clients = \)[0-9]\+/\1${MAX_CLIENTS}/" \
      -e "s/\(^max-same-clients = \)[0-9]\+/\1${MAX_SAME_CLIENTS}/" \
      -e "s/\(^rate-limit-ms = \)[0-9]\+/\1${RATE_LIMIT}/" \
      -e "s/\(^server-stats-reset-time = \)[0-9]\+/\1${SERVER_STATS_RESET}/" \
      -e "s/\(^keepalive = \)[0-9]\+/\1${KEEPALIVE}/" \
      -e "s/\(^dpd = \)[0-9]\+/\1${DPD}/" \
      -e "s/\(^mobile-dpd = \)[0-9]\+/\1${MOBILE_DPD}/" \
      -e "s/\(^switch-to-tcp-timeout = \)[0-9]\+/\1${SWITCH_TO_TCP}/" \
      -e "s/\(^try-mtu-discovery = \)false/\1${MTU_DISCOVERY}/" \
      -e "s/\(^cert-user-oid = \).*/\1${CERT_USER_OID}/" \
      -e "s/#\(compression.*\)/\1/; s/\(^compression = \)false/\1${COMPRESSION}/" \
      -e "s/\(^tls-priorities = \).*/\1${TLS_PRIORITIES}/" \
      -e "s/\(^auth-timeout = \)[0-9]\+/\1${AUTH_TIMEOUT}/" \
      -e "s/\(^min-reauth-time = \)[0-9]\+/\1${MIN_REAUTH_TIME}/" \
      -e "s/\(^max-ban-score = \)[0-9]\+/\1${MAX_BAN_SCORE}/" \
      -e "s/\(^ban-reset-time = \)[0-9]\+/\1${BAN_RESET_TIME}/" \
      -e "s/\(^cookie-timeout = \)[0-9]\+/\1${COOKIE_TIMEOUT}/" \
      -e "s/\(^deny-roaming = \)false/\1${DENY_ROAMING}/" \
      -e "s/\(^rekey-time = \)[0-9]\+/\1${REKEY_TIME}/" \
      -e "s/\(^use-occtl = \)true/\1${USE_OCCTL}/" \
      -e "s/\(^log-level = \)[0-9]\+/\1${LOG_LEVEL}/" \
      -e "s/\(^device = \)vpns/\1${DEV_NAME}/" \
      -e "s/\(^predictable-ips = \)true/\1${PREDICTABLE_IPS}/" \
      -e "s/\(^default-domain = \).*/\1${DEFAULT_DOMAIN}/" \
      -e "s/\(^ipv4-network = \)[0-9]\{1,3\}\([.][0-9]\{1,3\}\)\{3\}/\1${IPV4_NETWORK}/" \
      -e "s/\(^ipv4-netmask = \)[0-9]\{1,3\}\([.][0-9]\{1,3\}\)\{3\}/\1${IPV4_NETMASK}/" \
      -e "s/\(^dns = \)[0-9]\{1,3\}\([.][0-9]\{1,3\}\)\{3\}/\1${IPV4_DNS}/" \
      -e "s/\(^ping-leases = \)false/\1${PING_LEASES}/" \
      -e "s/#\(mtu.*\)/\1/; s/\(^mtu = \)[0-9]\{3,4\}/\1${MTU}/" \
      -e "s/\(^cisco-client-compat = \)true/\1${CISCO_CLIENT_COMPAT}/" \
      -e "s/\(^dtls-legacy = \)true/\1${DTLS_LEGACY}/" \
      -e "s/\(^cisco-svc-client-compat = \)false/\1${CISCO_SVC_CLIENT_COMPAT}/" \
      -e "s/\(^client-bypass-protocol = \)false/\1${CLIENT_BYPASS_PROTO}/" \
      -e "s/\(^camouflage = \)false/\1${CAMOUFLAGE}/" \
      -e "s/\(^camouflage_secret = \).*/\1${CAMOUFLAGE_SECRET}/" \
      -e "s/\(^camouflage_realm = \).*/\1${CAMOUFLAGE_REALM}/" \
	    -e "s/\(.*route.*\)/#\1/" \
      -e "/\[vhost:www.example.com\]/,/cert-user-oid.*/d" \
      -e "/^[[:space:]]*#/d; /^[[:space:]]*$/d" \
      /tmp/ocserv-default.conf > /etc/ocserv/ocserv.conf
    
 # Append routes
  {
    echo "route = ${ROUTE}"
    echo "${NO_ROUTE}" | tr ';' '\n' | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sed '/^$/d' | sed 's/^/no-route = /'
  } >> /etc/ocserv/ocserv.conf
}

# Main Execution

if [ ! -f /etc/ocserv/certs/server-key.pem ] || [ ! -f /etc/ocserv/certs/server-cert.pem ]; then
  generate_certificates
fi

if [ "${AUTH}" = "plain" ]; then
  AUTH_STRING="plain[passwd=/etc/ocserv/ocpasswd]"
  CERT_USER_OID="0.9.2342.19200300.100.1.1"
  create_user_plain
elif [ "${AUTH}" = "cert" ]; then
  AUTH_STRING="certificate"
  CERT_USER_OID="2.5.4.3"
  create_user_cert
fi

set_defaults
setup_network
update_config

# Run OpenConnect Server
exec "$@"