#!/bin/bash
# Desenvolvido por Luis Alexandre Deschamps Brandão
# Script de deploy com aguardo de finalização

# Extrai o ID do deploy.
deploymentID=$(jq '.deploymentId' ${1} | sed 's/\"//g' )
deploymentRegion=${2}

failSafe=0
while [ $failSafe -lt 60 ] ; do
  failSafe=$(($failSafe+1))

  deploymentJson=$(aws deploy get-deployment --deployment-id ${deploymentID} --region ${deploymentRegion})
  deploymentStatus=$(echo ${deploymentJson} | jq '.deploymentInfo.status' | sed 's/\"//g' )

  case ${deploymentStatus} in
    'Succeeded' )
      echo "Deployment of ${deploymentID} successful"
      exit 0 ;;
    'InProgress' )
      echo -e "\n\n === In Progress ================================================================= \n\n"
      echo ${deploymentJson}
      sleep 10 ;;
    'Created' )
      sleep 10 ;;
    *)
      echo "Unexpected state found: ${deploymentStatus}"
      exit 1 ;;
  esac
done

echo -e "\n\n === Error ================================================================= \n\n"
echo 'FailSafe triggered!'
echo "Last status ${deploymentStatus}"
echo "Json:"
echo "${deploymentJson}"
exit 1
