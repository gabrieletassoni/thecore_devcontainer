#!/bin/bash -e
echo "Testing docker installation."
docker version

cd "${CI_PROJECT_DIR}"

echo "Building Image $IMAGE_TAG_BACKEND"
DOCKERFILE_LOCATION="$1"

echo "Using $DOCKERFILE_LOCATION for build"
DIRS=$(dirname "$1")
CDELTA=./vendor/custombuilds/$(basename "$DIRS")/
docker build -f "$DOCKERFILE_LOCATION" --no-cache --pull -t "${IMAGE_TAG_BACKEND}" --build-arg "CUSTOMBUILDDIR=$CDELTA" .

echo "Login at $CI_REGISTRY"
docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"

echo "Pushing Image $IMAGE_TAG_BACKEND"
docker image push "${IMAGE_TAG_BACKEND}"
