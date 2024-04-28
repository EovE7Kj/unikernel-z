#!/usr/bin/env bash
# mirage4 setup

opam install 'mirage>=4.0'
echo -e "downloading mirage 4.0"
git clone https://github.com/mirage/mirage-www
mirage configure -f mirage/config.ml -t hvt && make depend
dune build mirage
solo5-hvt --net:service=tap100 mirage/dist/www.hvt
