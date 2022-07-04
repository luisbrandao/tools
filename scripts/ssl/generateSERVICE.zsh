#!/bin/zsh
# no redhat:
# yum install -y ca-certificates
# cp _tls/rootca.pem /etc/pki/ca-trust/source/anchors/
# update-ca-trust extract

set -xeuo pipefail

mkdir -p _tls

# application key
openssl genrsa -out _tls/service.key 4096

# application certificate signing request
openssl req -new -sha256 \
    -key _tls/service.key -out _tls/service.csr \
    -addext "subjectAltName=DNS:localhost,IP:::1,IP:127.0.0.1" \
    -subj "/O=ACME Service CO./CN=localhost"

# applicaiton certificate, signed by root rootca
openssl x509 -req -sha256 -CA _tls/rootca.pem -CAkey _tls/rootca.key -CAcreateserial -days 365 \
    -in _tls/service.csr -out _tls/service.pem \
    -extfile <( \
        echo 'authorityKeyIdentifier=keyid,issuer';
        echo 'basicConstraints=CA:FALSE';
        echo 'keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment';
        echo 'subjectAltName = DNS:localhost,IP:127.0.0.1';
    )
