#!/bin/bash
# Example: bash bash nexusRMversionMVN.sh br.com.example.acc green* purple.111 yellow.*

# Variables --------------------------------------------------------------------
credential='admin:password'
url_base='http://nexus3.example.local/service/rest/v1'
i=0
# ------------------------------------------------------------------------------

# Check minimum arguments
if [ "$#" -le 1 ]; then
    echo "Params: $#"
    echo 'I need at least 2 arguments!'
    echo 'bash nexusRMversionMVN.sh br.com.example.acc green* purple.111 yellow.*'
    exit 1
fi

# parse the arguments
group=${1} ; shift
while [[ $# -gt 0 ]] ; do
  versions[${i}]=${1}
  i=$((i+1))
  shift
done

rm -f list.txt
# Prompt the user
for version in ${versions[*]} ; do
  echo "For version: ${version}"
  # First request
  curl -X GET "${url_base}/search?group=${group}&version=${version}" -s > request.json
  jq -r '.items[].assets[].downloadUrl' request.json >> list.txt
  tkn=$(jq -r '.continuationToken' request.json) ; if [ ${tkn} = "null" ] ; then unset tkn ; fi
  # While there is a continuationToken
  while [ ! -z "${tkn}" ] ; do
    curl -X GET "${url_base}/search?group=${group}&version=${version}&continuationToken=${tkn}" -s > request.json
    jq -r '.items[].assets[].downloadUrl' request.json >> list.txt
    tkn=$(jq -r '.continuationToken' request.json) ; if [ ${tkn} = "null" ] ; then unset tkn ; fi
  done
done

# Processes result
cat list.txt

read -p "Are you sure? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]] ; then
  echo ==========================
  echo ======= Apagando =========
  echo ==========================
  for URL in $(cat list.txt) ; do
    echo ${URL}
  	curl -X DELETE --user "${credential}" ${URL}
  done
else
  echo ==========================
  echo ======== abort ===========
  echo ==========================
fi
rm -f list.txt
