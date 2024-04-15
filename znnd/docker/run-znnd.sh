#!/usr/bin/env bash 
#

[ -z "$1" ] && {
  echo -e "specify docker or podman"
  echo -e "ex: ./init.sh podman\n"
  exit 1
}

type="$1" # 'podman' or 'docker'
img="docker.io/eove7kj/znnd:latest"

chkExist() {
  command -v "$1" >/dev/null 2>&1 && echo $?
}

if [[ $(chkExist "$type") == 0 ]] ; then

  $type run -d --name znnd \
    -p 35995:35995 \
    -p 35996:35996 \
    -p 35997:35997 \
    -p 35998:35998 \
    $img

else
  echo "$type not installed!"
fi 
