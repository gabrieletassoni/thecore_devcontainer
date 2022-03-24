#!/bin/bash -e

sudo -iuroot

# Testing docker installation
docker version
docker-compose version
docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"

# Building container and pushing to the registry
cd /etc/thecore/docker/

export DOCKER_SERVICE=${DOCKER_SERVICE:-backend}

export IMAGE_TAG_BACKEND=${CI_REGISTRY_IMAGE}/$DOCKER_SERVICE:$CI_COMMIT_TAG

echo "Building Image $IMAGE_TAG_BACKEND"
docker-compose \
    -f docker-compose.yml \
    -f docker-compose.build.yml \
    build --pull --no-cache "$DOCKER_SERVICE"

echo "Pushing Image $IMAGE_TAG_BACKEND"
docker-compose \
    -f docker-compose.yml \
    push "$DOCKER_SERVICE"