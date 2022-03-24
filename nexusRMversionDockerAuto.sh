#!/bin/bash
# Example: bash nexusRMversionDocker.sh acc-backend black* blue-37 purple-11*

# Variables --------------------------------------------------------------------
credential='admin:password'
url_base='http://nexus3.example.local/service/rest/v1'
api_url='http://nexus3.example.local/repository/local-registry/v2'
# ------------------------------------------------------------------------------

# Check minimum arguments
if [ ! "$#" -eq 2 ]; then
    echo "receive: $#"
    echo 'I need 2 arguments!'
    echo 'example: bash nexusRMversionDocker.sh acc-backend blue-*'
    exit 1
fi

# parse the arguments
group=${1}
version=${2}

rm -f list.txt hashP.txt hash.txt

# First request
curl -X GET "${url_base}/search?format=docker&name=${group}&version=${version}" -s > request.json
jq -r '.items[].assets[].downloadUrl' request.json > list.txt
jq -r '.items[].assets[].checksum.sha256' request.json > hash.txt
tkn=$(jq -r '.continuationToken' request.json) ; if [ ${tkn} = "null" ] ; then unset tkn ; fi

# While there is a continuationToken
while [ ! -z "${tkn}" ] ; do
  curl -X GET "${url_base}/search?format=docker&name=${group}&version=${version}&continuationToken=${tkn}" -s > request.json
  jq -r '.items[].assets[].downloadUrl' request.json >> list.txt
  jq -r '.items[].assets[].checksum.sha256' request.json >> hash.txt
  tkn=$(jq -r '.continuationToken' request.json) ; if [ ${tkn} = "null" ] ; then unset tkn ; fi
done

# Processes result
head -n -5 list.txt | tee listP.txt
head -n -5 hash.txt > hashP.txt
mv -f listP.txt list.txt
mv -f hashP.txt hash.txt

read -p "Are you sure? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]] ; then
  echo ==========================
  echo ======= Apagando =========
  echo ==========================
    for HASH in $(cat hash.txt) ; do
      URL="${api_url}/${group}/manifests/sha256:${HASH}"
      echo ${URL}
    	curl -X DELETE --user "${credential}" ${URL}
    done
else
  echo ==========================
  echo ======== abort ===========
  echo ==========================
fi
rm -f list.txt hashP.txt hash.txt request.json
