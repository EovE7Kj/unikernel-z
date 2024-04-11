#!/usr/bin/env bash 
#

podman run -it --rm \
  -p 8080:8080 \
  -v $(pwd):/home/opam \
  ocaml/opam
  
