#!/usr/bin/env bash

[ -z "$1" ] && {
  echo -e "specify docker or podman"
  echo -e "ex: ./init.sh podman\n"
  exit 1 
}

type="$1" # docker or podman

chkExist() {
  command -v "$1" >/dev/null 2>&1 && echo $?
}

if [[ $(chkExist "$type") == 0 ]] ; then  
  $type build . -t zcaml

  $type run -it --rm \
    --privileged --name zcaml \
    -p 35995:35995 \
    -p 35997:35997 \
    -p 35998:35998 \
    zcaml
else
  echo "$type not installed!"
fi
