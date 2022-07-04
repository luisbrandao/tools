#!/bin/zsh
set -xeuo pipefail

mkdir -p _tls

# root certificate authority key
openssl genrsa -out _tls/rootca.key 4096

# root certificate signing request
openssl req -x509 -new -sha256 -days 7300 \
    -key _tls/rootca.key -out _tls/rootca.pem \
    -subj "/O=ACME Root CO./CN=localhost"
