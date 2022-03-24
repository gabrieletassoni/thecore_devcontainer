#!/bin/bash -e

# Testing docker installation
sudo docker version

echo "Building Image $IMAGE_TAG_BACKEND"
sudo docker build -f /etc/thecore/docker/Dockerfile --no-cache --pull -t "${IMAGE_TAG_BACKEND}" "${CI_PROJECT_DIR}"

echo "Login at $CI_REGISTRY"
sudo docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"

echo "Pushing Image $IMAGE_TAG_BACKEND"
sudo docker image push "${IMAGE_TAG_BACKEND}"
