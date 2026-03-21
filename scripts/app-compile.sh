#!/bin/bash -e

echo Getting the version from version file
version=$(tr -d '\n' < version)

# A new tag has been added to the repository, so we need to compile the images
CURDIR=$(pwd)

export IMAGE_TAG_BACKEND=${CI_REGISTRY_IMAGE}/backend:$version
echo "Building $IMAGE_TAG_BACKEND"

# If $CURDIR/Dockerfile exists, use it
if [ -f "$CURDIR/Dockerfile" ]; then
    echo "Using Dockerfile in $CURDIR"

    /usr/bin/docker-build.sh "$CURDIR/Dockerfile" "$version"
else
    echo "Using Dockerfile in /etc/thecore/docker"
    # If $CURDIR/Dockerfile does not exist, use the one in /etc/thecore/docker
    # This is the default location for the Dockerfile
    /usr/bin/docker-build.sh "/etc/thecore/docker/Dockerfile" "$version"
fi

echo "Building $IMAGE_TAG_BACKEND done"
