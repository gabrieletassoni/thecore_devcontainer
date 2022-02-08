#!/bin/bash -e

docker-compose -f /etc/thecore/docker/docker-compose.yml -f /etc/thecore/docker/docker-compose.build.yml config
docker-compose -f /etc/thecore/docker/docker-compose.yml -f /etc/thecore/docker/docker-compose.build.yml build --pull --no-cache
docker-compose -f /etc/thecore/docker/docker-compose.yml -f /etc/thecore/docker/docker-compose.build.yml push
