#!/bin/bash
# Example: bash nexusRMversionDocker.sh acc-backend black* blue-37 purple-11*
#if [ "$#" -ne 1 ]; then
#    echo 'I need at least 1 arguments!'
#    echo 'example: bash addTenantKube.sh "tenant1,tenant2"'
#    exit 1
#fi

modulos="acc arm core dvh fito mcbp prod rca rec commons"
tenants="testesementesk,timepr,devtime6k,arquitetura,luizhenrique,time4,rodrigodiego,testeluizsql"

for modulo in ${modulos} ; do
  curl 'http://cloud-backend-green.knet.agrotis.local/cloud/admin/atualizar-modulo' \
    -H 'User-Agent: Bash Script Brandao' \
    -H 'Content-Type: application/json;charset=UTF-8' \
    -H 'Origin: http://cloud-frontend-green.knet.agrotis.local' \
    -H 'Referer: http://cloud-frontend-green.knet.agrotis.local/' \
    --data-binary "{\"componente\":\"backend\",\"modulo\":\"${modulo}\",\"versao\":\"blue\",\"tenants\":\"${tenants}\",\"homologacao\":true}"
done

for modulo in ${modulos} ; do
  curl 'http://cloud-backend-green.knet.agrotis.local/cloud/admin/atualizar-modulo' \
    -H 'User-Agent: Bash Script Brandao' \
    -H 'Content-Type: application/json;charset=UTF-8' \
    -H 'Origin: http://cloud-frontend-green.knet.agrotis.local' \
    -H 'Referer: http://cloud-frontend-green.knet.agrotis.local/' \
    --data-binary "{\"componente\":\"frontend\",\"modulo\":\"${modulo}\",\"versao\":\"blue\",\"tenants\":\"${tenants}\",\"homologacao\":true}"
done
