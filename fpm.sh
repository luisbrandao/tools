#!/bin/bash
# Testa se foi passado o número correto de paramentos
if [ ! ${#} -eq 1 ] ;	then
	echo 'Diga o numero da iteração:'
	echo ${0} '1'
	exit 1
fi

NAME=solr
VERSION=7.1.0
ITERATION=$1
ARCHITECTURE=noarch
LOCAL=$(pwd)

# O comando precisa ser executado de dentro do workdir
cd workdir

# =========================
fpm \
--verbose \
--input-type dir \
--output-type rpm \
--name ${NAME} \
--iteration ${ITERATION} \
--version ${VERSION} \
--architecture ${ARCHITECTURE} \
--maintainer 'luis.brandao@rentcars.com' \
--url 'http://lucene.apache.org/solr/' \
--rpm-summary 'Solr is the popular, blazing-fast, open source enterprise search platform built on Apache Lucene' \
--description "This package was generated using fpm from the original upstream tgz. Solr is highly reliable, scalable and fault tolerant, providing distributed indexing, replication and load-balanced querying, automated failover and recovery, centralized configuration and more. Solr powers the search and navigation features of many of the world's largest internet sites. " \
--license "Apache License, Version 2.0" \
--rpm-user solr \
--rpm-group solr \
--rpm-attr 755,root,root:/etc/init.d/solr \
--before-install ../before-install.sh \
--after-install  ../after-install.sh \
--config-files /etc/init.d/solr \
--config-files /etc/default/solr.in.sh \
--config-files /var/solr/log4j.properties \
--directories /opt/solr \
--directories /var/solr \
--depends lsof \
./
# =========================

mv ${NAME}-${VERSION}-${ITERATION}.${ARCHITECTURE}.rpm ${LOCAL}/
cd ${LOCAL}/
