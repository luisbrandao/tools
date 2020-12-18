#!/bin/bash
# === open =====================================================================
action=${1}
if [ "${action}" == "open" ]; then
  if [ "$#" -ne 3 ]; then
      echo "Params: $#"
      echo 'I need at least 3 arguments!'
      echo 'luksMount open sdj /mnt/external'
      exit 1
  fi
  devdisk=${2}
  mountpoint=${3}
  volname=$(tr -dc a-z0-9 </dev/urandom | head -c 8)

  cryptsetup luksOpen /dev/${devdisk} ${volname}
  mount /dev/mapper/${volname} ${mountpoint}

  # === close ==================================================================
elif [ "${action}" == "close" ]; then
  if [ "$#" -ne 2 ]; then
      echo "Params: $#"
      echo 'I need 2 arguments!'
      echo 'luksMount open sdj /mnt/external'
      exit 1
  fi
  volname=$(mount | grep "/mnt/external" | cut -f1 -d" " | cut -f4 -d"/")
  mountpoint=${2}

  sync
  umount ${mountpoint}
  cryptsetup luksClose ${volname}
else
  echo 'Need an action [open, close]'
fi
