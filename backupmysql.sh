#!/bin/bash
# vim: ts=8
# 20070709      Marcelo Beckmann
# + acrescentado -f para o mysqldump não interromper em caso de erros
# 20080109      Marcelo Beckmann
# + Modificado para fazer dump de cada database em separado
# 20080508      Marcelo Beckmann
# + Acrescentado parâmetro "--default-character-set=latin1" no mysqldump
# 20080719      Marcelo Beckmann
# + Modificado diretório de backup para /opt/backup-mysql
# + Aumentado retenção de 7 para 30 dias
# 20081119      Marcelo Beckmann
# + Colocada senha de acesso ao banco
# 20101117      Luis Alexandre
# + Modificado para funcionar para o meu caso
# 20111021      Luis Alexandre
# + Nova modificação para acertar os diretórios de backup.
# 20180126      Luis Alexandre
# + Change gz to xz
# 20181119      Luis Alexandre
# + Refatoração completa do script
# + Tipo de compressão selecionavel
# + Refatoração das váriaveis

umask 077

export LANG=pt_BR.UTF-8
TSTAMP="$(date +"%Y-%m-%d-%a")"
TMPPATH=/tmp/backup
DIRBACKUP=/dados/backup
KEEPDAYS=14
#COMPRESSCMD="gzip" ; EXTENSION="tgz" # Versão gzip simples
#COMPRESSCMD="xz" ; EXTENSION="txz" # Versão xz simples requer xz
#COMPRESSCMD="pigz --best" ; EXTENSION="tgz" # Requer pigz e tar <= 1.30
COMPRESSCMD="pxz --best" ; EXTENSION="txz" # Requer pxz e tar <= 1.30
#COMPRESSCMD="lrzip -q -z -L9" ; EXTENSION="lrzip" # Requer lrzip e tar <= 1.30
FILENAME="backup-mysql-`hostname -s`-`date +"%Y%m%d"`.${EXTENSION}"
PASSWORD=123456
MYSQL_USER=root

[ -d ${TMPPATH} ] && rm -Rf ${TMPPATH} # Remove o diretório temporario
[ -f ${DIRBACKUP}/${FILENAME} ] && rm ${DIRBACKUP}/${FILENAME} # Caso o backup já exista, remove o antigo

echo "======================================================================================================================"
echo "Iniciando o backup do mysql $(uname -n)"
echo "${TSTAMP}"
echo ""

echo "======================================================================================================================"
echo "Iniciando dump das bases:"
mkdir -p ${TMPPATH}
for BASE in `mysqlshow -u${MYSQL_USER} -p${PASSWORD} | egrep -v "(^\+|Databases)" | tr -s " " | cut -d" " -f2` ; do
  echo "  Dump da base: ${BASE}"
  mysqldump --single-transaction -u${MYSQL_USER} -p${PASSWORD} -f ${BASE} >${TMPPATH}/${BASE}.sql
done

echo "======================================================================================================================"
echo "Iniciando compressão: tar -I \"${COMPRESSCMD}\" -cf ${DIRBACKUP}/${FILENAME}"
cd ${TMPPATH}
tar -I "${COMPRESSCMD}" -cf ${DIRBACKUP}/${FILENAME} ./ #>/dev/null 2>&1

echo "======================================================================================================================"
echo "Transferindo arquivo para o dropbox"
bash /root/bin/dropbox_uploader.sh upload "${DIRBACKUP}/${FILENAME}" "mysql/${FILENAME}"

echo "======================================================================================================================"
echo "Serão removidos os aquivos:"

DELETE=$(find ${DIRBACKUP} -type f -iname "backup-mysql-*" -mtime +${KEEPDAYS} 2>&1)
find ${DIRBACKUP} -type f -iname "backup-mysql-*" -mtime +${KEEPDAYS} 2>&1
find ${DIRBACKUP} -type f -iname "backup-mysql-*" -mtime +${KEEPDAYS} -delete >/dev/null 2>&1

if [ ! -z "$DELETE" ]; then
  echo "Apagando do dropbox:"
  for target in ${DELETE} ; do
    cleanf=$(echo $target | rev | cut -d"/" -f 1 | rev )
    bash /root/bin/dropbox_uploader.sh delete "mysql/${cleanf}"
  done
else
  echo -e "\nNada para apagar\n"
fi

echo "======================================================================================================================"
echo "Backup finalizado. Arquivo gerado:"
echo ${FILENAME}
echo ""
echo "======================================================================================================================"
df -h
