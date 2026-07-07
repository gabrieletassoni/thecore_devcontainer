#!/bin/bash -e
echo "Testing docker installation."
docker version

cd "${CI_PROJECT_DIR}"

echo "Building Image $IMAGE_TAG_BACKEND"
DOCKERFILE_LOCATION="$1"

echo "Using $DOCKERFILE_LOCATION for build"
DIRS=$(dirname "$1")
CDELTA=./vendor/custombuilds/$(basename "$DIRS")/

BUNDLE_ENV_FILE=$(mktemp)
chmod 600 "$BUNDLE_ENV_FILE"
trap 'rm -f "$BUNDLE_ENV_FILE"' EXIT

for var in $(compgen -v | grep '^BUNDLE_'); do
  printf 'export %s=%q\n' "$var" "${!var}" >> "$BUNDLE_ENV_FILE"
done

DOCKER_BUILDKIT=1 docker build -f "$DOCKERFILE_LOCATION" --no-cache --pull --network=host -t "${IMAGE_TAG_BACKEND}" \
    --build-arg "CUSTOMBUILDDIR=$CDELTA" \
    --build-arg "CI_REGISTRY_IMAGE=${CI_REGISTRY_IMAGE}" \
    --build-arg "CI_COMMIT_TAG=$2" \
    --secret id=bundle_env,src="$BUNDLE_ENV_FILE" .

echo "Login at $CI_REGISTRY"
echo "$CI_REGISTRY_PASSWORD" | docker login $CI_REGISTRY -u $CI_REGISTRY_USER --password-stdin

echo "Pushing Image $IMAGE_TAG_BACKEND"
docker image push "${IMAGE_TAG_BACKEND}"
