#!/bin/bash

# set -o verbose # verbose
# set -o xtrace # debug
# set -o pipefail # exit on pipe error
set -o errexit # exit on error
set -o errtrace # exit on error

trap 'die "ERR trap called in ${FUNCNAME-main context} on line ${LINENO}."' ERR

die () {
    echo -e >&2 "$@"
    exit 1
}

ACTION="${1}"
case "${ACTION}" in
    # === open ================================================================
    "open")
        if [ "$#" -ne 3 ]; then
            die "3 arguments required, $# provided\n" "usage: \tluksMount open sdj /mnt/external"
        fi
        DEVDISK=${2}
        MOUNTPOINT=${3}
        VOLNAME=$(tr -dc a-z0-9 </dev/urandom | head -c 8)

        cryptsetup luksOpen /dev/${DEVDISK} ${VOLNAME}
        mount /dev/mapper/${VOLNAME} ${MOUNTPOINT}
        ;;

    # === close ===============================================================
    "close")
        if [ "$#" -ne 2 ]; then
            die "2 arguments required, $# provided\n" "usage: \tluksMount open sdj /mnt/external"
        fi
        VOLNAME=$(mount | grep "/mnt/external" | cut -f1 -d" " | cut -f4 -d"/")
        MOUNTPOINT=${2}

        sync
        umount ${MOUNTPOINT}
        cryptsetup luksClose ${VOLNAME}
        ;;

    # === unknown =============================================================
    *)
        echo 'Need an action [open, close]'
esac
