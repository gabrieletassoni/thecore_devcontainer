#!/bin/bash -e

# Testing docker installation
sudo docker version
sudo docker-compose version
sudo docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
echo "CI_PROJECT_DIR: ${CI_PROJECT_DIR}"
# Building container and pushing to the registry
cd /etc/thecore/docker/
# -f docker-compose.net.yml \
# -f docker-compose.net.yml \
export BUILD_DIR="${CI_PROJECT_DIR}"
sudo docker-compose \
    -f docker-compose.yml \
    -f docker-compose.build.yml \
    build --pull --no-cache backend
sudo docker-compose push
