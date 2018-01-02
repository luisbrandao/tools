

# PR a partir da linha de comando
alias pull_stage="hub pull-request -b stage -m"
alias pull_master="hub pull-request -b master -m"


# Recria a branch de integração
recria_integration ()
{
        git checkout master;
        git branch -D integration;
        git fetch -pt;
        git reset --hard origin/master;
        git checkout -b integration;
        git push -f origin integration
}

# Facilita limpeza de memcache e redis.
limpacache ()
{
  case ${1} in
    'dev')
      echo 'Limpando cache de desenvolvimento'
      echo 'Redis site: (cache.rentcars.lan)'
      echo 'FLUSHALL' | redis-cli -h cache.rentcars.lan
      echo 'Memcache admin/rest: (cache.rentcars.lan)'
      echo 'flush_all' | nc cache.rentcars.lan 11211
      ;;
    *)
      echo 'Parametro inválido! Nada foi feito'
      echo "limpacache prod|stage|dev"
      ;;
  esac
}
