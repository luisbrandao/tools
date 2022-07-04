#!/bin/bash
#
# bash gitlab-autoclone.sh rentcars [api key do gitlab] https://gitlab.com
#


if command -v jq >/dev/null 2>&1; then
  echo "jq parser found";
else
  echo "this script requires the 'jq' json parser (https://stedolan.github.io/jq/).";
  exit 1;
fi

if [ -z "$1" ]
  then
    echo "a group name arg is required"
    exit 1;
fi

if [ -z "$2" ]
  then
    echo "an auth token arg is required. See $3/profile/account"
    exit 1;
fi

if [ -z "$3" ]
  then
    echo "a gitlab URL is required."
    exit 1;
fi

TOKEN="$2";
URL="$3/api/v3"
PREFIX="ssh_url_to_repo";

echo "Cloning all git projects in group $1";

GROUP_ID=$(curl --header "PRIVATE-TOKEN: $TOKEN" $URL/groups?search=$1 | jq '.[].id')
echo "group id was $GROUP_ID";
curl --header "PRIVATE-TOKEN: $TOKEN" $URL/groups/$GROUP_ID/projects?per_page=100 | jq --arg p "$PREFIX" '.[] | .[$p]' | xargs -L1 git clone
