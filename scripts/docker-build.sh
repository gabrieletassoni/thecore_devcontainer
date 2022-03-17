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
docker-compose -f installers/docker-compose.yml -f installers/docker-compose.build.yml build --pull --no-cache backend
docker-compose -f installers/docker-compose.yml -f installers/docker-compose.build.yml push
