#!/bin/bash
group=${1}
version=${2}

#credential='admin:admin'
#url_base='http://nexus3.exemple.com/service/rest/v1'

for URL in $(curl -X GET "${url_base}/search?group=${group}&version=${version}" -s | jq '.items[].assets[].downloadUrl') ; do
	URL=$(echo "$URL" | sed -e 's/^"//' -e 's/"$//')
	echo ${URL}
done

read -p "Are you sure? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]] ; then
  echo ==========================
  echo ======= Apagando =========
  echo ==========================
  for URL in $(curl -X GET "${url_base}/search?group=${group}&version=${version}" -s | jq '.items[].assets[].downloadUrl') ; do
  	URL=$(echo "$URL" | sed -e 's/^"//' -e 's/"$//')
  	curl -X DELETE -v --user "${credential}" ${URL}
  done
else
  echo ==========================
  echo ======== abort ===========
  echo ==========================
fi
