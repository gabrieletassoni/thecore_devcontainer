#!/bin/bash -e

# Testing docker installation
sudo docker version
sudo docker-compose version
sudo docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
echo "CI_PROJECT_DIR: ${CI_PROJECT_DIR}"
# Building container and pushing to the registry
cd /etc/thecore/docker/

export DOCKER_SERVICE=${DOCKER_SERVICE:-backend}

export IMAGE_TAG_BACKEND=${CI_REGISTRY_IMAGE}/$DOCKER_SERVICE:$CI_COMMIT_TAG

sudo -E docker-compose \
    -f docker-compose.yml \
    -f docker-compose.build.yml \
    build --pull --no-cache --build-arg "BUILD_DIR=${CI_PROJECT_DIR}" "$DOCKER_SERVICE"

sudo -E docker-compose push