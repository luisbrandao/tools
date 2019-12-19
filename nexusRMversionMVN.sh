#!/bin/bash
# Example: bash bash nexusRMversionMVN.sh br.com.example.acc green* purple.111 yellow.*

# Variables --------------------------------------------------------------------
credential='admin:password'
url_base='http://nexus3.example.local/service/rest/v1'
i=0
# ------------------------------------------------------------------------------

# Check minimum arguments
if [ "$#" -le 2 ]; then
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

# Prompt the user
for version in ${versions[*]} ; do
  for URL in $(curl -X GET "${url_base}/search?group=${group}&version=${version}" -s | jq -r '.items[].assets[].downloadUrl') ; do
  	echo ${URL}
  done
done

read -p "Are you sure? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]] ; then
  echo ==========================
  echo ======= Apagando =========
  echo ==========================
  for version in ${versions[*]} ; do
    for URL in $(curl -X GET "${url_base}/search?group=${group}&version=${version}" -s | jq -r '.items[].assets[].downloadUrl') ; do
      echo ${URL}
    	curl -X DELETE --user "${credential}" ${URL}
    done
  done
else
  echo ==========================
  echo ======== abort ===========
  echo ==========================
fi
