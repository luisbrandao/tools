#!/bin/bash
group=${1}
version=${2}

credential='admin:password'
url_base='http://nexus3.example.local/service/rest/v1'

for URL in $(curl -X GET "${url_base}/search?group=${group}&version=${version}" -s | jq -r '.items[].assets[].downloadUrl') ; do
	echo ${URL}
done

#read -p "Are you sure? " -n 1 -r
#echo    # (optional) move to a new line
REPLY=y
if [[ $REPLY =~ ^[Yy]$ ]] ; then
  echo ==========================
  echo ======= Apagando =========
  echo ==========================
  for URL in $(curl -X GET "${url_base}/search?group=${group}&version=${version}" -s | jq -r '.items[].assets[].downloadUrl') ; do
    echo ${URL}
  	curl -X DELETE --user "${credential}" ${URL}
  done
else
  echo ==========================
  echo ======== abort ===========
  echo ==========================
fi
