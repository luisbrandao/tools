#!/bin/bash

# set -o verbose # verbose
# set -o xtrace # debug
set -o pipefail # exit on pipe error
set -o nounset # variable must exist
set -o errexit # exit on error
set -o errtrace # exit on error

trap 'die "ERR trap called in ${FUNCNAME-main context} on line ${LINENO}."' ERR

die () {
    echo >&2 "$@"
    exit 1
}

ACTION="${1:'dummy'}"

case "${ACTION}" in
    # === open ================================================================
    "open")
        if [ "$#" -ne 3 ]; then
            die "3 arguments required, $# provided\n" "usage: \tluksMount open sdj /mnt/external"
        fi
        local DEVDISK=${2}
        local MOUNTPOINT=${3}
        local VOLNAME=$(tr -dc a-z0-9 </dev/urandom | head -c 8)

        cryptsetup luksOpen /dev/${DEVDISK} ${VOLNAME}
        mount /dev/mapper/${VOLNAME} ${MOUNTPOINT}
        ;;

    # === close ===============================================================
    "close")
        if [ "$#" -ne 2 ]; then
            die "2 arguments required, $# provided\n" "usage: \tluksMount open sdj /mnt/external"
        fi
        local VOLNAME=$(mount | grep "/mnt/external" | cut -f1 -d" " | cut -f4 -d"/")
        local MOUNTPOINT=${2}

        sync
        umount ${MOUNTPOINT}
        cryptsetup luksClose ${VOLNAME}
        ;;

    # === unknown =============================================================
    *)
        echo 'Need an action [open, close]'
esac
