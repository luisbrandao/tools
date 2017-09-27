#!/bin/bash
# Função para testar se os parametros estão corretos
function usage {
	echo uso:
	echo ${0} 'rest'
	echo ${0} 'site'

	exit 1
}

# Tratamento explicativo de erros
function trataErro {
  if [ ${1} -eq 1 ] ;	then
		echo "Falha no merge com a master"
		exit 1
	elif [ ${1} -eq 2 ] ;	then
    echo "Falha ao se obter a master limpa"
		exit 1
	fi
}

# Função de update
function updateBranch {
	git checkout ${1}
	git merge master || trataErro 1
	git push
}

# Testa se foi passado o número correto de paramentos
if [ ! ${#} -eq 1 ] ;	then
	usage
	exit 1
fi

# Decide o alvo
if   [ ${1} = 'rest' ] ; then
	target='/home/luis.brandao/git/github/rentcars'
elif [ ${1} = 'site' ] ; then
	target='/home/luis.brandao/git/github/site'
fi

# Grava onde estava e muda para o alvo
volta=$(pwd)
cd ${target}

# Retorna o repositorio para o estado pristino e executa os updates
git checkout . || trataErro 2
git checkout master || trataErro 2
git reset --hard origin/master
git fetch -pt
git pull
git branch -D integration stage
updateBranch integration
updateBranch stage
git checkout master

# Volta para onde eu estava
cd ${volta}
exit 0
