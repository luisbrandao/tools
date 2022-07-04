#!/bin/bash
# ---------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------[ Configuração ]-----------------------------------------------
#temp=$(mktemp -t recriaBanco.XXXXXXX)                                     # Arquivo temporário
debug=true
# ------------------------------------------------------[ Configuração ]-----------------------------------------------
# ---------------------------------------------------------------------------------------------------------------------

# Echo, but in collors
echo_red()(echo -e "\e[0;31m$@\e[m")
echo_green()(echo -e "\e[0;32m$@\e[m")
echo_yellow()(echo -e "\e[0;33m$@\e[m")
echo_debug()(if ${debug} ; then echo -e "\e[0;33m$@\e[m" ; fi)

# ---------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------[ Sanity Check ]-----------------------------------------------
function usage {
	echo 'Usage:'
  echo_yellow "${0} source destiny instanceSize kill"
  echo '==============='
  echo 'source:        Name of the DBInstance which will be copied'
  echo ''
  echo 'destiny:       Name of the new DBInstance'
  echo ''
  echo 'instanceSize: Size of the new instance (Anything outside this list will be rejected)'
  echo '               (db.t2.micro|db.t2.small|db.t2.medium|db.t2.large)'
  echo '               (db.m3.large|db.m3.2xlarge)'
  echo ''
  echo 'kill:          If this word is present, the DB instace called "destiny" will be removed and replaced'
  echo '==============='
  echo 'Exemple:'
  echo_yellow "${0} mobicar hmmobicar db.t2.large kill"

	exit 1
}

# Testa se foi passado o número correto de paramentos
if [ ! ${#} -eq 3 ] && [ ! ${#} -eq 4 ] ; then
  echo_red "Error: Invalid number of params"
	usage
	exit 1
fi

# Função que consulta a AWS e checa se determinado nome de DBInstance existe
function db_exist {
  local result=$(aws rds describe-db-instances | jq -c '.DBInstances[].DBInstanceIdentifier' | grep \"${1}\")

  echo_debug "Result: ${result}"

  if [ -z "${result}" ]; then
    echo_debug "DBInstance ${1} not found: Will return false"
    return 1
  else
    echo_debug "DBInstance ${1} found: Will return true"
    return 0
  fi
}

# === Source ===================================================================
# Checa se a fonte é valida
source=${1}
if db_exist ${source} ; then
  echo_green "Found source ${source}"
else
  echo_red "Error: source ${source} doesnt exist"
  exit 1
fi

# === Destiny ==================================================================
# Checagem de destino
destiny=${2}
case "${destiny}" in
  mobicar|replica|wp-rentcars|wp-rentcars2)
    echo_red 'Destiny is a critical database! Refusing to go further'
    exit 1
    ;;
  *)
    echo_green "Destiny ${destiny} look like valid"
    ;;
esac

# Se kill foi especificado, o destino DEVE existir, caso contrario ele NAO PODE existir
if  [ "${#}" -eq 4 ] && [ "${4}" == "kill" ] ; then
  echo_debug "Kill enabled"
  if db_exist ${destiny} ; then
    echo_green "Found killable destiny: ${destiny}"
  else
    echo_red "Error: destiny ${destiny} doesnt exist (and should)"
    exit 1
  fi
else
  echo_debug "Kill disabled"
  if db_exist ${destiny} ; then
    echo_red "Destiny ${destiny} already exists. Add kill to substitute it. Refusing to go further"
    exit 1
  else
    echo_green "Destiny ${destiny} is clear"
  fi
fi

# === Instance size ============================================================
instanceSize=${3}
case "${instanceSize}" in
  db.t2.micro|db.t2.small|db.t2.medium|db.t2.large|db.m3.large|db.m3.2xlarge)
    echo_green "Instance Size accepted: ${instanceSize}"
    ;;
  *)
    echo_red "Instance Size not expected: ${instanceSize}"
    usage
    exit 1
    ;;
esac

# Se chegamos aqui, todos os parametros foram validados
echo_green 'Parameters looking good, moving on'


# ------------------------------------------------------[ Sanity Check ]-----------------------------------------------
# ---------------------------------------------------------------------------------------------------------------------


# ---------------------------------------------------------------------------------------------------------------------
# ----------------------------------------------------------[ Work ]---------------------------------------------------

# --- RESTORE -----------------------------------------------------------------------------------------------------------
snapshot=$(aws rds describe-db-snapshots --db-instance-identifier ${source} | jq -c '.DBSnapshots[].DBSnapshotIdentifier' | tail -n 1 | tr -d '"')

# Double check snapshot
if [ -z "${snapshot}" ]; then
  echo_red "Snapshot for ${source} not found"
  exit 1
else
  echo_debug "Snapshot will be: $snapshot"
fi

# Execute the recovery
tmpdestiny="tmp-${destiny}"
echo_green 'Executing the recovery'
aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier ${tmpdestiny} \
    --db-snapshot-identifier ${snapshot} \
    --db-instance-class ${instanceSize} \
    --availability-zone sa-east-1a \
    --no-multi-az \
    --publicly-accessible \
    --db-subnet-group-name publico

# First wait
status=$(aws rds describe-db-instances --db-instance-identifier ${tmpdestiny} --max-items 1 | jq -c '.DBInstances[].DBInstanceStatus' | tr -d '"')
echo_debug "${tmpdestiny}: Status is ${status}. Waiting 500 seconds"
sleep 500 # It takes more than that, no point in checking earlier

# Wait for it to finish
shouldWait=true
while ${shouldWait} ; do
  status=$(aws rds describe-db-instances --db-instance-identifier ${tmpdestiny} --max-items 1 | jq -c '.DBInstances[].DBInstanceStatus' | tr -d '"')

  case "${status}" in
    creating|backing-up|modifying)
      echo_debug "${tmpdestiny}: Status is ${status}. Waiting more 10 seconds"
      sleep 10
      ;;
    available)
      echo_green "${tmpdestiny}: Good to go"
      shouldWait=false
      ;;
    *)
      echo_red "${tmpdestiny}: Unexpected state: ${status}. Abort."
      exit 1
      ;;
  esac
done


# --- DELETE -----------------------------------------------------------------------------------------------------------
# If kill is enabled, kill the destiny DBInstance
if  [ "${#}" -eq 4 ] && [ "${4}" == "kill" ] ; then
  echo_green "${destiny} will be removed"
  aws rds delete-db-instance --db-instance-identifier ${destiny} --skip-final-snapshot

  shouldWait=true
  while ${shouldWait} ; do
    status=$(aws rds describe-db-instances --db-instance-identifier ${destiny} --max-items 1 2>/dev/null | jq -c '.DBInstances[].DBInstanceStatus' | tr -d '"')

    case "${status}" in
      deleting)
        echo_debug "${destiny}: Status is ${status}. Waiting more 10 seconds"
        sleep 10
        ;;
      "")
        echo_green "${destiny}: Good to go"
        shouldWait=false
        ;;
      *)
        echo_red "${destiny}: Unexpected state: ${status}. Abort."
        exit 1
        ;;
    esac
  done
fi

# --- MODIFY -----------------------------------------------------------------------------------------------------------
# Finish up
aws rds modify-db-instance \
  --db-instance-identifier ${tmpdestiny} \
  --new-db-instance-identifier ${destiny} \
  --db-parameter-group-name mobicar \
  --backup-retention-period 0 \
  --apply-immediately

shouldWait=true ; name="${tmpdestiny}"
while ${shouldWait} ; do
  status=$(aws rds describe-db-instances --db-instance-identifier ${name} --max-items 1 2>/dev/null | jq -c '.DBInstances[].DBInstanceStatus' | tr -d '"')

  case "${status}" in
    deleting)
      echo_debug "${name}: Status is ${status}. Waiting more 10 seconds"
      sleep 10
      ;;
    "")
      echo_green "${name}: was renamed"
      name=${destiny}
      ;;
    available)
      echo_green "${name}: Good to go"
      shouldWait=false
      ;;
    *)
      echo_red "${name}: Unexpected state: ${status}. Abort."
      exit 1
      ;;
  esac
done

echo_green "=========================="
echo_green "          Done"
echo_green "=========================="

exit 0
