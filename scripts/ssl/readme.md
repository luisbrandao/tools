# SSL
## Uso no redhat:

```sh
yum install -y ca-certificates
#zsh generate all
cp _tls/rootca.pem /etc/pki/ca-trust/source/anchors/
update-ca-trust extract
```

# Verificar pem, crt
Esse comando printa a validade e escopo do certificado

```sh
openssl x509 -in _tls/rootca.pem -text -noout
openssl x509 -in _tls/service.pem -text -noout
```

# Verificar key

```sh
openssl rsa -in _tls/rootca.key -check
openssl rsa -in _tls/service.key -check
```

# Verificar se a client está valida pela CA
```sh
openssl verify -CAfile _tls/rootca.pem _tls/service.pem
```

# Verificar a Certificate Signing Request (CSR)
```sh
openssl req -text -noout -verify -in _tls/service.csr
```
