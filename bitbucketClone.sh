#!/bin/bash
projects="A B C D"
user=user:senha
team=team
base="$(pwd)"

for project in ${projects} ; do
  mkdir -p "${project}" ; cd ${project}
  curl -s https://api.bitbucket.org/2.0/repositories/${team}\?pagelen=100\&q="project.key=\"${project}\"" -u ${user} > repos.json
  jq -r '.values[] |.links.clone[1].href' repos.json > repolist.txt

  for repo in $(cat repolist.txt) ; do
    git clone ${repo}
  done

  cd "${base}"
done
