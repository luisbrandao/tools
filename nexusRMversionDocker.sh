#!/bin/bash
# Example: bash nexusRMversionDocker.sh acc-backend black* blue-37 purple-11*

# Variables --------------------------------------------------------------------
credential='admin:password'
url_base='http://nexus3.example.local/service/rest/v1'
api_url='http://nexus3.example.local/repository/local-registry/v2'
i=0
# ------------------------------------------------------------------------------

# Check minimum arguments
if [ "$#" -le 1 ]; then
    echo 'I need at least 2 arguments!'
    echo 'example: bash nexusRMversionDocker.sh acc-backend black* blue-37 purple-11*'
    exit 1
fi

# parse the arguments
group=${1} ; shift
while [[ $# -gt 0 ]] ; do
  versions[${i}]="${1}"
  i="$((i+1))"
  shift
done

# Prompt user
for version in "${versions[*]}" ; do
  for URL in $(curl -X GET "${url_base}/search?format=docker&name=${group}&version=${version}" -s | jq -r '.items[].assets[].downloadUrl') ; do
  	echo ${URL}
  done
done

read -p "Are you sure? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]] ; then
  echo ==========================
  echo ======= Apagando =========
  echo ==========================
  for version in "${versions[*]}" ; do
    for HASH in $(curl -X GET "${url_base}/search?format=docker&name=${group}&version=${version}" -s | jq -r '.items[].assets[].checksum.sha256') ; do
      URL="${api_url}/${group}/manifests/sha256:${HASH}"
      echo ${URL}
    	curl -X DELETE --user "${credential}" ${URL}
    done
  done
else
  echo ==========================
  echo ======== abort ===========
  echo ==========================
fi
