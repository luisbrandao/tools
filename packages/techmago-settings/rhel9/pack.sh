#!/bin/bash
# Testa se foi passado o número correto de paramentos
if [ ! ${#} -eq 1 ] ;	then
  echo 'Diga o numero da iteração:'
  echo ${0} '1'
  exit 1
fi

NAME=techmago-settings
VERSION=2.0.0
ITERATION=${1?}
ARCHITECTURE=noarch
LOCAL=$(pwd)
# ==============================================================================
# O comando precisa ser executado de dentro do workdir
cd workdir && fpm \
--verbose \
--input-type dir \
--output-type rpm \
--name ${NAME} \
--iteration ${ITERATION} \
--version ${VERSION} \
--architecture ${ARCHITECTURE} \
--maintainer "Luis Alexandre Deschamps Brandão <techmago@ymail.com>" \
--url 'https://github.com/luisbrandao/' \
--rpm-summary 'Personalizador de ambiente do techmago' \
--description "Personalizador de ambiente do techmago" \
--license "Apache License, Version 2.0" \
--directories /usr/share/techmago \
--depends dialog \
./
# ==============================================================================

mv ${NAME}-${VERSION}-${ITERATION}.${ARCHITECTURE}.rpm ${LOCAL}/
cd ${LOCAL}/
