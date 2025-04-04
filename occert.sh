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

# Validate input
validate_input() {
  if [ -z "${CLIENT_CN}" ] || [ -z "${CLIENT_P12_PWD}" ] ; then
    log_error "Usage: occert <username> <p12_cert_password> [cert_valid_days] "
    exit 1
  fi
}

# Generate client certificate (OpenSSL)
generate_client_certificates() {

  mkdir -p "${CLIENT_CERT_DIR}" || {
  log_error "Unable to create directory ${CLIENT_CERT_DIR}"
  exit 1
  }

  local CLIENT_KEY_FILE="${CLIENT_CERT_DIR}/${CLIENT_CN}-key.pem"
  local CLIENT_CERT_FILE="${CLIENT_CERT_DIR}/${CLIENT_CN}.pem"
  local CLIENT_P12_FILE="${CLIENT_CERT_DIR}/${CLIENT_CN}.p12"
  local CLIENT_CSR_FILE="${CLIENT_CERT_DIR}/${CLIENT_CN}.csr"

  if [ -f "${CLIENT_KEY_FILE}" ] && [ -f "${CLIENT_CERT_FILE}" ]; then
    log_info "Certificate for '${CLIENT_CN}' already exists."
    exit 0
  fi

  log_info "Creating client certificate for '${CLIENT_CN}'..."

  # Generate client private key (RSA 2048 bits)
  if ! openssl genpkey \
              -algorithm RSA \
              -out "${CLIENT_KEY_FILE}" \
              -pkeyopt rsa_keygen_bits:2048; \
              then log_error "Failed to generate client private key."
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
              -CA "${CA_CERT}" \
              -CAkey "${CA_PKEY}" \
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

  log_info "Client certificate for '${CLIENT_CN}' has been created successfully and is valid for ${CLIENT_DAYS} days."
  echo "${CLIENT_P12_PWD}" > "/etc/.${CLIENT_CN}"
  chmod 600 "/etc/.${CLIENT_CN}"

}


# Main execution
main() {

  local CLIENT_CN=$1
  local CLIENT_P12_PWD=$2
  local CLIENT_DAYS=${3:-365}

  validate_input
  generate_client_certificates
}

# Run the script
main "$@"