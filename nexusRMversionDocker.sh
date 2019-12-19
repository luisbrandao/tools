#!/bin/bash
group=${1}
version=${2}

credential='admin:password'
url_base='http://nexus3.example.local/service/rest/v1'
api_url='http://nexus3.example.local/repository/local-registry/v2'

for URL in $(curl -X GET "${url_base}/search?format=docker&name=${group}&version=${version}" -s | jq -r '.items[].assets[].downloadUrl') ; do
	echo ${URL}
done

read -p "Are you sure? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]] ; then
  echo ==========================
  echo ======= Apagando =========
  echo ==========================
  for HASH in $(curl -X GET "${url_base}/search?format=docker&name=${group}&version=${version}" -s | jq -r '.items[].assets[].checksum.sha256') ; do
    URL="${api_url}/${group}/manifests/sha256:${HASH}"
    echo ${URL}
  	curl -X DELETE --user "${credential}" ${URL}
  done
else
  echo ==========================
  echo ======== abort ===========
  echo ==========================
fi
