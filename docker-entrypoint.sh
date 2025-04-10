#!/bin/sh
set -e  # Exit on error

# Logging functions
log_info() {
  echo "[INFO] $1"
}

log_error() {
  echo "[ERROR] $1" >&2
}

generate_password() {
  local length=${1:-16}
  # Allowed characters that exclude ambiguous ones: l, I, 1, O, 0
  local allowed_chars='A-HJ-NP-Za-km-z2-9!@#$%^&*()-_=+'
    dd if=/dev/urandom bs=1 count=$((length * 3)) 2>/dev/null \
      | base64 \
      | tr -d '\n' \
      | tr -dc "$allowed_chars" \
      | head -c "$length"
  echo
}

update_config_option() {

    local OPTION="$1"
    local VALUE="$2"
    local LOWER_VALUE=$(echo "${VALUE}" | tr '[:upper:]' '[:lower:]')

    if [ "${LOWER_VALUE}" = "true" ] || [ "${LOWER_VALUE}" = "false" ]; then
      VALUE="${LOWER_VALUE}"
    fi

    # Process the config file
        if [ -n "${VALUE}" ]; then
            #if grep -qE "^\s*#\s*${OPTION}\s*=" "${CONFIG_FILE}"; then
            if grep -qE "^${OPTION}\s*=" "${CONFIG_FILE}"; then
                # Case 1: Update the existing uncommented option
                sed -i -E "s|^(${OPTION}\s*=).*|\1 ${VALUE}|" "${CONFIG_FILE}"
            elif 
                grep -qE "^#${OPTION}\s*=" "${CONFIG_FILE}"; then
                # Case 2: Uncomment and update the existing commented option
                sed -i -E "s|^#(${OPTION}\s*=).*|\1 ${VALUE}|" "${CONFIG_FILE}"
            else
                # Case 3: Append the option if it doesn't exist
                echo "${OPTION} = ${VALUE}"
            fi
        fi

}

set_defaults() {

    
  HOST_NAME=${HOST_NAME:-"bigcorp.com"}
  ORG_NAME=${ORG_NAME:-"BigCorp Inc"}

  AUTH=${AUTH:-"plain"}
  CA_CN=${CA_CN:-"${ORG_NAME} Root CA"}
  CA_DAYS=${CA_DAYS:-1825}
  CA_ORG=${CA_ORG:-"${ORG_NAME}"}
  DEFAULT_DOMAIN=${DEFAULT_DOMAIN:-"${HOST_NAME}"}
  IPV4_DNS=${IPV4_DNS:-"8.8.8.8"}
  IPV4_NETMASK=${IPV4_NETMASK:-"255.255.255.0"}
  IPV4_NETWORK=${IPV4_NETWORK:-"192.168.99.0"}
  NO_ROUTE=${NO_ROUTE:-"192.168.0.0/16; 10.0.0.0/8; 172.16.0.0/12"}
  ROUTE=${ROUTE:-"default"}
  SRV_CN=${SRV_CN:-"${HOST_NAME}"}
  SRV_DAYS=${SRV_DAYS:-1825}
  SRV_ORG=${CA_ORG:-"${ORG_NAME}"}
  USER_PASSWORD=${USER_PASSWORD:-"$(generate_password 8)"}

}

# Generate server certificate (OpenSSL)
generate_server_certificates() {
  CA_SRL_FILE=$(echo "${CA_CERT}" | sed 's/\.pem$/.srl/')
  SERVER_CSR_FILE="${SERVER_CERT_DIR}/server.csr"
  
  mkdir -p "${SERVER_CERT_DIR}" || {
    log_error "Unable to create directory ${SERVER_CERT_DIR}"
    exit 1
  }

  # Only generate CA certificate if it doesn't exist
  if [ ! -f "${CA_PKEY}" ] || [ ! -f "${CA_CERT}" ]; then
    log_info "Creating self-signed CA certificate for '${CA_CN}'..."

    # Generate CA private key (RSA 2048 bits)
    if ! openssl genpkey \
                -algorithm RSA \
                -out "${CA_PKEY}" \
                -pkeyopt rsa_keygen_bits:2048
    then 
      log_error "Failed to generate CA private key."
      exit 1
    fi

    # Generate a self-signed CA certificate
    if ! openssl req \
                -new \
                -x509 \
                -key "${CA_PKEY}" \
                -out "${CA_CERT}" \
                -days "${CA_DAYS}" \
                -subj "/CN=${CA_CN}/O=${CA_ORG}"
    then 
      log_error "Failed to generate CA certificate."
      exit 1
    fi
  else
    log_info "CA certificate for '${CA_CN}' already exists - using existing one."
  fi
  
  # Generate server certificate if it doesn't exist
  if [ ! -f "${SERVER_PKEY}" ] || [ ! -f "${SERVER_CERT}" ]; then
    log_info "Creating server certificate for '${SRV_CN}'..."

    # Generate Server private key
    if ! openssl genpkey \
                -algorithm RSA \
                -out "${SERVER_PKEY}" \
                -pkeyopt rsa_keygen_bits:2048
    then 
      log_error "Failed to generate server private key."
      exit 1
    fi

    # Generate a CSR for the server certificate
    if ! openssl req \
                -new \
                -key "${SERVER_PKEY}" \
                -out "${SERVER_CSR_FILE}" \
                -subj "/CN=$SRV_CN/O=$SRV_ORG"
    then 
      log_error "Failed to generate server CSR."
      exit 1
    fi

    # Sign the server CSR with the CA to create the server certificate
    if ! openssl x509 \
                -req \
                -in "${SERVER_CSR_FILE}" \
                -CA "${CA_CERT}" \
                -CAkey "${CA_PKEY}" \
                -CAcreateserial \
                -out "${SERVER_CERT}" \
                -days "${SRV_DAYS}" \
                -sha256
    then 
      log_error "Failed to generate server certificate."
      exit 1
    fi

    # Clean up temporary files
    rm -f "${SERVER_CSR_FILE}" "${CA_SRL_FILE}"
  else
    log_info "Server certificate for '${SRV_CN}' already exists - using existing one."
  fi
}

create_user() {

  if [ "${AUTH}" = "plain" ]; then

  AUTH_STRING="plain[passwd=${WORKDIR}/ocpasswd]"
  CERT_USER_OID="0.9.2342.19200300.100.1.1"

    if [ ! -z "$USER_NAME" ] && [ ! -f "${WORKDIR}/ocpasswd" ]; then
    log_info "Creating plain user '${USER_NAME}'..."
    echo "${USER_PASSWORD}" > "/etc/.${USER_NAME}"
    chmod 600 "/etc/.${USER_NAME}"
    yes ${USER_PASSWORD} | ocpasswd -c "${WORKDIR}/ocpasswd" ${USER_NAME}
    fi

  elif [ "${AUTH}" = "cert" ]; then

  AUTH_STRING="certificate"
  CERT_USER_OID="2.5.4.3"

    if [ ! -z "$USER_NAME" ]; then
    occert ${USER_NAME} ${USER_PASSWORD}
    fi

  fi
}

setup_network() {

  iptables -t nat -A POSTROUTING -j MASQUERADE -s "${IPV4_NETWORK}"/"${IPV4_NETMASK}"
  iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200
  chmod 600 /dev/net/tun

}

list_to_option () {

    local LIST="$1"
    local DELIMETERS=";, "

    echo "${LIST}" | tr "${DELIMETERS}" '\n' | sed '/^$/d' | awk -v OPTION="$2" '{$1=$1; print OPTION " = " $0}'
}

# Create configuration
update_config() {

  # Create config file by removing unnecessary parameters from default config
  sed -e "s/\(^[^#]*route = .*\)/#\1/" \
      -e "/\[vhost:www.example.com\]/,/cert-user-oid.*/d" \
      "${DEFAULT_CONFIG_FILE}" > "${CONFIG_FILE}"

  # Set config options
  update_config_option "auth-timeout" ${AUTH_TIMEOUT}
  update_config_option "auth" ${AUTH_STRING}
  update_config_option "ban-reset-time" ${BAN_RESET_TIME}
  update_config_option "ca-cert" ${CA_CERT}
  update_config_option "camouflage_realm" ${CAMOUFLAGE_REALM}
  update_config_option "camouflage_secret" ${CAMOUFLAGE_SECRET}
  update_config_option "camouflage" ${CAMOUFLAGE}
  update_config_option "cert-user-oid" ${CERT_USER_OID}
  update_config_option "cisco-client-compat" ${CISCO_CLIENT_COMPAT}
  update_config_option "cisco-svc-client-compat" ${CISCO_SVC_CLIENT_COMPAT}
  update_config_option "client-bypass-protocol" ${CLIENT_BYPASS_PROTO}
  update_config_option "compression" ${COMPRESSION}
  update_config_option "cookie-timeout" ${COOKIE_TIMEOUT}
  update_config_option "default-domain" ${DEFAULT_DOMAIN}
  update_config_option "deny-roaming" ${DENY_ROAMING}
  update_config_option "device" ${DEV_NAME}
  update_config_option "device" ${DEV_NAME}
  update_config_option "dns" ${IPV4_DNS}
  update_config_option "dpd" ${DPD}
  update_config_option "dtls-legacy" ${DTLS_LEGACY}
  update_config_option "ipv4-netmask" ${IPV4_NETMASK}
  update_config_option "ipv4-network" ${IPV4_NETWORK}
  update_config_option "isolate-workers" ${ISOLATE_WORKERS}
  update_config_option "keepalive" ${KEEPALIVE}
  update_config_option "log-level" ${LOG_LEVEL}
  update_config_option "max-ban-score" ${MAX_BAN_SCORE}
  update_config_option "max-clients" ${MAX_CLIENTS}
  update_config_option "max-same-clients" ${MAX_SAME_CLIENTS}
  update_config_option "min-reauth-time" ${MIN_REAUTH_TIME}
  update_config_option "mobile-dpd" ${MOBILE_DPD}
  update_config_option "mtu" ${MTU}
  update_config_option "pid-file" ${PID_FILE}
  update_config_option "ping-leases" ${PING_LEASES}
  update_config_option "predictable-ips" ${PREDICTABLE_IPS}
  update_config_option "rate-limit-ms" ${RATE_LIMIT}
  update_config_option "rekey-time" ${REKEY_TIME}
  update_config_option "run-as-user" ${OC_USER}
  update_config_option "run-as-group" ${OC_USER}
  update_config_option "server-cert" ${SERVER_CERT}
  update_config_option "server-key" ${SERVER_PKEY}
  update_config_option "server-stats-reset-time" ${SERVER_STATS_RESET}
  update_config_option "socket-file" ${SOCKET_FILE}
  update_config_option "switch-to-tcp-timeout" ${SWITCH_TO_TCP}
  update_config_option "tcp-port" ${TCP_PORT}
  update_config_option "tls-priorities" ${TLS_PRIORITIES}
  update_config_option "try-mtu-discovery" ${MTU_DISCOVERY}
  update_config_option "udp-port" ${UDP_PORT}
  update_config_option "use-occtl" ${USE_OCCTL}

  # Append routes
  list_to_option "${ROUTE}" "route" >> "${CONFIG_FILE}"
  list_to_option "${NO_ROUTE}" "no-route" >> "${CONFIG_FILE}"

  # Sort, removing commented strings & duplicates
  sed -E "/^\s*#/d; /^\s*$/d" "${CONFIG_FILE}" \
  | sort -u > "${CONFIG_FILE}.tmp" \
  && mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"

}

# Main Execution
set_defaults
generate_server_certificates
create_user
update_config
setup_network

# Run OpenConnect Server
exec "$@"