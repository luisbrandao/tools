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
umask 077

export LANG=pt_BR.UTF-8
TSTAMP=$(date +"%Y-%m-%d-%a")
TMPPATH=/tmp/backup/
DIRBACKUP=/dados/backup/
FILENAME=backup-mysql-`hostname -s`-`date +"%Y%m%d"`.txz
PASSWORD=123456

[ -d ${TMPPATH} ] && rm -Rf ${TMPPATH}
[ -f ${DIRBACKUP}/${FILENAME} ] && rm ${FILEBACKUP}


DIRBACKUP=/tmp/backup/
FILEBACKUP=/dados/backup/
CLEANNAME=backup-mysql-`hostname -s`-`date +"%Y%m%d"`.txz
[ -d ${DIRBACKUP} ] && rm -Rf ${DIRBACKUP}
[ -f ${FILEBACKUP} ] && rm ${FILEBACKUP}

echo "Iniciando o backup do mysql $(uname -n)"
echo "${TSTAMP}"

# Remove arquivos mais antigos que 14 dias
echo ""
echo "Serão removidos os aquivos:"
find /dados/backup/ -type f -mtime +14 2>&1
find /dados/backup/ -type f -mtime +14 -exec rm -f {} \; >/dev/null 2>&1
echo ""

echo "Iniciando dump das bases:"
mkdir ${DIRBACKUP}
for base in `mysqlshow -u root -p${PASSWORD} | egrep -v "(^\+|Databases)" | tr -s " " | cut -d" " -f2`
do
        echo "  Dump da base: ${base}"
        mysqldump --single-transaction -u root -p${PASSWORD} -f ${base} >${DIRBACKUP}/${base}.sql
done

env XZ_OPT=-9 tar -Jcvf ${FILEBACKUP} ${DIRBACKUP} >/dev/null 2>&1
rm -Rf ${DIRBACKUP}

echo "Uploading file"
bash /root/bin/dropbox_uploader.sh upload ${FILEBACKUP} mysql/${CLEANNAME}

echo ""
echo "Backup finalizado. Arquivo gerado:"
echo ${FILEBACKUP}
echo ""
echo ""
df -h
