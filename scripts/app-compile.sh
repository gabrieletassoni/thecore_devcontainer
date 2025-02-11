#!/bin/bash -e

echo Getting the version from version file
version=$(tr -d '\n' < version)

# A new tag has been added to the repository, so we need to compile the images
CURDIR=$(pwd)
bundle config set path "$CURDIR/vendor/bundle"
bundle config get path
echo "Compiling the default image"
bundle install
    
rm -rf tmp/cache/* /tmp/*

export IMAGE_TAG_BACKEND=${CI_REGISTRY_IMAGE}/backend:$version
echo "Building $IMAGE_TAG_BACKEND"
/usr/bin/docker-build.sh "/etc/thecore/docker/Dockerfile" "$version"
