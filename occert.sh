#!/bin/sh

CLIENT_CN=$1
CLIENT_DAYS=$2
P12_PWD=$3

if [ -n "${CLIENT_CN}" ]; then

    CLIENT_DAYS=${CLIENT_DAYS:-365}
    P12_PWD=${P12_PWD:-"openconnect"}

    CERT_DIR="/etc/ocserv/certs/client"
    KEY_FILE="${CERT_DIR}/${CLIENT_CN}-key.pem"
    CERT_FILE="${CERT_DIR}/${CLIENT_CN}.pem"
    P12_FILE="${CERT_DIR}/${CLIENT_CN}.p12"

    # Create client certificate directory if it doesn't exist
    mkdir -p "${CERT_DIR}" || {
        echo "Error: Unable to create directory ${CERT_DIR}"
        exit 1
    }

    if [ ! -f "${KEY_FILE}" ] || [ ! -f "${CERT_FILE}" ]; then
        # Generate user certificate
        cd "${CERT_DIR}" || exit 1
        echo "Creating certificate for '${CLIENT_CN}'..."

        certtool --generate-privkey --outfile "${KEY_FILE}" || {
            echo "Error: Failed to generate private key."
            exit 1
        }

        cat > "${CLIENT_CN}.tmpl" <<-EOCL
        cn = "${CLIENT_CN}"
        expiration_days = ${CLIENT_DAYS}
        signing_key
        encryption_key
        tls_www_client
EOCL

        certtool --generate-certificate \
            --load-privkey "${KEY_FILE}" \
            --load-ca-certificate ../ca.pem \
            --load-ca-privkey ../ca-key.pem \
            --template "${CLIENT_CN}.tmpl" \
            --outfile "${CERT_FILE}" || {
            echo "Error: Failed to generate certificate."
            exit 1
        }

        openssl pkcs12 -export \
            -in "${CERT_FILE}" \
            -inkey "${KEY_FILE}" \
            -out "${P12_FILE}" \
            -legacy \
            -passout pass:"${P12_PWD}" || {
            echo "Error: Failed to generate PKCS12 file."
            exit 1
        }

        echo "Certificate for '${CLIENT_CN}' has been created successfully."
        echo "Certificate is valid for ${CLIENT_DAYS} days."
        echo "P12 Certificate password is '${P12_PWD}'."
        echo
    else
        echo "Certificate for '${CLIENT_CN}' already exists. Please remove it and try again."
    fi
else
    echo "Usage: occert <username> [cert_valid_days] [p12_cert_password]"
fi