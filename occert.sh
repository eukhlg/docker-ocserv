#!/bin/sh

# Exit on error
set -e

# Logging functions
log_info() {
  echo "[INFO] $1"
}

log_error() {
  echo "[ERROR] $1" >&2
}

# Set default values
set_defaults() {

  CLIENT_DAYS=${CLIENT_DAYS:-365}
  CLIENT_P12_PWD=${CLIENT_P12_PWD:-""}
  
}

# Validate input
validate_input() {
  if [ -z "${CLIENT_CN}" ]; then
    log_error "Usage: occert <username> [p12_cert_password] [cert_valid_days] "
    exit 1
  fi
}

: << 'EOF'
# Generate client certificate (GnuTLS)
generate_client_certificates() {
  CLIENT_KEY_FILE="${CLIENT_CERT_DIR}/${CLIENT_CN}-key.pem"
  CLIENT_CERT_FILE="${CLIENT_CERT_DIR}/${CLIENT_CN}.pem"
  CLIENT_P12_FILE="${CLIENT_CERT_DIR}/${CLIENT_CN}.p12"

  if [ -f "${CLIENT_KEY_FILE}" ] && [ -f "${CLIENT_CERT_FILE}" ]; then
    log_info "Certificate for '${CLIENT_CN}' already exists."
    exit 0
  fi

  log_info "Creating certificate for '${CLIENT_CN}'..."

  # Generate private key
  certtool --generate-privkey --outfile "${CLIENT_KEY_FILE}" || {
    log_error "Failed to generate private key."
    exit 1
  }

  # Create certificate template
  cat > "${CLIENT_CERT_DIR}/${CLIENT_CN}.tmpl" <<-EOCL
  cn = "${CLIENT_CN}"
  expiration_days = ${CLIENT_DAYS}
  signing_key
  encryption_key
  tls_www_client
EOCL

  # Generate certificate
  certtool --generate-certificate \
    --load-privkey "${CLIENT_KEY_FILE}" \
    --load-ca-certificate ${SERVER_CERT_DIR}/ca.pem \
    --load-ca-privkey ${SERVER_CERT_DIR}/ca-key.pem \
    --template "${CLIENT_CERT_DIR}/${CLIENT_CN}.tmpl" \
    --outfile "${CLIENT_CERT_FILE}" || {
    log_error "Failed to generate certificate."
    exit 1
  }

  certtool --to-p12 \
    --load-privkey "${CLIENT_KEY_FILE}" \
    --p12-name "${CLIENT_CN}" \
    --pkcs-cipher 3des-pkcs12 \
    --load-certificate "${CLIENT_CERT_FILE}" \
    --outfile "${CLIENT_P12_FILE}" --outder
    --password "${CLIENT_P12_PWD}" || {
    log_error "Failed to generate PKCS12 file."
    exit 1
  }

  log_info "Certificate for '${CLIENT_CN}' has been created successfully."
  log_info "P12 Certificate password is '${CLIENT_P12_PWD}'."
  log_info "Certificate is valid for ${CLIENT_DAYS} days."
}
EOF

# Generate client certificate (OpenSSL)
generate_client_certificates() {

  mkdir -p "${CLIENT_CERT_DIR}" || {
  log_error "Unable to create directory ${CLIENT_CERT_DIR}"
  exit 1
  }

  CLIENT_KEY_FILE="${CLIENT_CERT_DIR}/${CLIENT_CN}-key.pem"
  CLIENT_CERT_FILE="${CLIENT_CERT_DIR}/${CLIENT_CN}.pem"
  CLIENT_P12_FILE="${CLIENT_CERT_DIR}/${CLIENT_CN}.p12"
  CLIENT_CSR_FILE="${CLIENT_CERT_DIR}/${CLIENT_CN}.csr"

  if [ -f "${CLIENT_KEY_FILE}" ] && [ -f "${CLIENT_CERT_FILE}" ]; then
    log_info "Certificate for '${CLIENT_CN}' already exists."
    exit 0
  fi

  log_info "Creating certificate for '${CLIENT_CN}'..."

  # Generate client private key (RSA 2048 bits)
  if ! openssl genpkey \
              -algorithm RSA \
              -out "${CLIENT_KEY_FILE}" \
              -pkeyopt rsa_keygen_bits:2048; \
              then log_error "Failed to generate private key."
    exit 1
  fi

  # Generate a certificate signing request (CSR)
  if ! openssl req \
              -new \
              -key "${CLIENT_KEY_FILE}" \
              -out "${CLIENT_CSR_FILE}" \
              -subj "/CN=${CLIENT_CN}"; \
              then log_error "Failed to generate CSR."
    exit 1
  fi

  # Sign the CSR with the CA certificate and key
  if ! openssl x509 \
              -req \
              -in "${CLIENT_CSR_FILE}" \
              -CA "${SERVER_CERT_DIR}/ca.pem" \
              -CAkey "${SERVER_CERT_DIR}/ca-key.pem" \
              -CAcreateserial -out "${CLIENT_CERT_FILE}" \
              -days "${CLIENT_DAYS}" -sha256; \
              then log_error "Failed to generate certificate."
    exit 1
  fi

  # Remove temporary files (CSR and CA serial)
  rm -f "${CLIENT_CSR_FILE}"

  # Export to PKCS#12 format
  if ! openssl pkcs12 \
              -export \
              -in "${CLIENT_CERT_FILE}" \
              -inkey "${CLIENT_KEY_FILE}" \
              -out "${CLIENT_P12_FILE}" \
              -legacy \
              -passout pass:"${CLIENT_P12_PWD}"; \
              then log_error "Failed to generate PKCS12 file."
    exit 1
  fi

  log_info "Certificate for '${CLIENT_CN}' has been created successfully."
  log_info "P12 Certificate password is '${CLIENT_P12_PWD}'."
  log_info "Certificate is valid for ${CLIENT_DAYS} days."
}


# Main execution
main() {

  CLIENT_CN=$1
  CLIENT_P12_PWD=$2
  CLIENT_DAYS=$3

  validate_input
  set_defaults
  generate_client_certificates
}

# Run the script
main "$@"