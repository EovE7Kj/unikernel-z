## znnd container image 
avaliable at `docker.io/eove7kj/znnd:latest`

pull:
```bash
docker pull docker.io/eove7kj/znnd:latest
```

run:
```bash
docker run -d --name znnd \
    -p 35995:35995 \
    -p 35996:35996 \
    -p 35997:35997 \
    -p 35998:35998 \
    docker.io/eove7kj/znnd:latest
```

*obligatory: the above cmds also work with `podman`*

