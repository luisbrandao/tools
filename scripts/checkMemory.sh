#!/bin/sh

# Funcao responsavel pela checagem do status de uso da memoria:
mem () {
  ramtotal=$(cat /proc/meminfo | grep "^MemTotal" | tr -s " " | cut -d" " -f 2)
  ramlivre=$(cat /proc/meminfo | grep "^MemFree" | tr -s " " | cut -d" " -f 2)
  rambuffer=$(cat /proc/meminfo | grep "^Buffers" | tr -s " " | cut -d" " -f 2)
  ramcache=$(cat /proc/meminfo | grep "^Cached" | tr -s " " | cut -d" " -f 2)

  # Quantidade REAL de RAM em uso:
  ramusada=$(expr $ramtotal - \( $ramlivre + $rambuffer + $ramcache \))
  # Porcentagem utilizada:

  percent=$(expr $ramusada \* 100 / $ramtotal)
  echo $percent
}

mem
