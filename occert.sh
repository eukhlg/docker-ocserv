#!/bin/sh
set -e  # Exit on error

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
  P12_PWD=${P12_PWD:-"openconnect"}
}

# Validate input
validate_input() {
  if [ -z "${CLIENT_CN}" ]; then
    log_error "Usage: occert <username> [cert_valid_days] [p12_cert_password]"
    exit 1
  fi
}

# Create certificate directory
create_cert_dir() {
  CERT_DIR="/etc/ocserv/certs/client"
  mkdir -p "${CERT_DIR}" || {
    log_error "Unable to create directory ${CERT_DIR}"
    exit 1
  }
}

# Generate client certificate
generate_certificate() {
  KEY_FILE="${CERT_DIR}/${CLIENT_CN}-key.pem"
  CERT_FILE="${CERT_DIR}/${CLIENT_CN}.pem"
  P12_FILE="${CERT_DIR}/${CLIENT_CN}.p12"

  if [ -f "${KEY_FILE}" ] && [ -f "${CERT_FILE}" ]; then
    log_info "Certificate for '${CLIENT_CN}' already exists. Please remove it and try again."
    exit 0
  fi

  log_info "Creating certificate for '${CLIENT_CN}'..."

  # Generate private key
  certtool --generate-privkey --outfile "${KEY_FILE}" || {
    log_error "Failed to generate private key."
    exit 1
  }

  # Create certificate template
  cat > "${CERT_DIR}/${CLIENT_CN}.tmpl" <<-EOCL
  cn = "${CLIENT_CN}"
  expiration_days = ${CLIENT_DAYS}
  signing_key
  encryption_key
  tls_www_client
EOCL

  # Generate certificate
  certtool --generate-certificate \
    --load-privkey "${KEY_FILE}" \
    --load-ca-certificate ../ca.pem \
    --load-ca-privkey ../ca-key.pem \
    --template "${CERT_DIR}/${CLIENT_CN}.tmpl" \
    --outfile "${CERT_FILE}" || {
    log_error "Failed to generate certificate."
    exit 1
  }

  # Generate PKCS12 file
  openssl pkcs12 -export \
    -in "${CERT_FILE}" \
    -inkey "${KEY_FILE}" \
    -out "${P12_FILE}" \
    -legacy \
    -passout pass:"${P12_PWD}" || {
    log_error "Failed to generate PKCS12 file."
    exit 1
  }

  log_info "Certificate for '${CLIENT_CN}' has been created successfully."
  log_info "Certificate is valid for ${CLIENT_DAYS} days."
  log_info "P12 Certificate password is '${P12_PWD}'."
}

# Main execution
main() {
  CLIENT_CN=$1
  CLIENT_DAYS=$2
  P12_PWD=$3

  validate_input
  set_defaults
  create_cert_dir
  generate_certificate
}

# Run the script
main "$@"