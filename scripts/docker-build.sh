#!/bin/sh -e

if ! hash docker-compose
then
    apt update
    apt install -y docker-compose
else
    echo "Docker Compose exists"
fi
# Testing docker installation
docker version
docker-compose --version
docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
# Building container and pushing to the registry
cd /etc/thecore/docker/
docker-compose \
    -f docker-compose.yml \
    -f docker-compose.build.yml \
    -f docker-compose.net.yml \
    build --pull --no-cache backend
docker-compose \
    -f docker-compose.yml \
    -f docker-compose.build.yml \
    -f docker-compose.net.yml \
    push
