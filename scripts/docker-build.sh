#!/bin/bash -e

# Testing docker installation
sudo docker version
sudo docker-compose version
sudo docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
# Building container and pushing to the registry
cd /etc/thecore/docker/
# -f docker-compose.net.yml \
# -f docker-compose.net.yml \
sudo docker-compose \
    -f docker-compose.yml \
    -f docker-compose.build.yml \
    build --pull --no-cache --build-arg "BUILD_DIR=${CI_PROJECT_DIR}"  backend
sudo docker-compose push
