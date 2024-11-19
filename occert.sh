#!/bin/sh

CLIENT_CN=$1
CLIENT_DAYS=$2
P12_PWD=$3

if [ ! -z ${CLIENT_CN} ]; then

if [ -z ${CLIENT_DAYS} ]; then
CLIENT_DAYS=365
fi

if [ -z ${P12_PWD} ]; then
P12_PWD="openconnect"
fi


if [ ! -f /etc/ocserv/certs/client/${CLIENT_CN}-key.pem ] || [ ! -f /etc/ocserv/certs/client/${CLIENT_CN}.pem ]; then
# Generate user certificate
mkdir -p /etc/ocserv/certs/client
cd /etc/ocserv/certs/client
    echo "Creating certificate for "\'${CLIENT_CN}\'"..."
    certtool --generate-privkey --outfile ${CLIENT_CN}-key.pem
    cat > ${CLIENT_CN}.tmpl <<-EOCL
    cn = "$CLIENT_CN"
    expiration_days = $((${CLIENT_DAYS}))
    signing_key
    encryption_key
    tls_www_client
EOCL

certtool --generate-certificate --load-privkey ${CLIENT_CN}-key.pem --load-ca-certificate ../ca.pem --load-ca-privkey ../ca-key.pem --template ${CLIENT_CN}.tmpl --outfile ${CLIENT_CN}.pem
#certtool --to-p12 --load-certificate ${CLIENT_CN}.pem --load-privkey ${CLIENT_CN}-key.pem --outder --outfile ${CLIENT_CN}.p12 --p12-name ${CLIENT_CN} --password ${P12_PWD}
openssl pkcs12 -export -in ${CLIENT_CN}.pem -inkey ${CLIENT_CN}-key.pem -out ${CLIENT_CN}.p12 -legacy -passout pass:${P12_PWD}
echo "Certificate for "\'${CLIENT_CN}\'" has been created sucessfully"
echo "Certificate is valid for ${CLIENT_DAYS} days"
echo "P12 Certiticate password is "\'${P12_PWD}\'""
echo 

else                                                                                                                              
echo 'Certificate for this user already exists. Please remove it and try again...'
fi

else

echo 'Usage: occert <username> [cert_valid_days] [p12_cert_password]'
fi
