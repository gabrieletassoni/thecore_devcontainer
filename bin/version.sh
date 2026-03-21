#!/bin/bash -e

export MAJOR
export MINOR
export PATCH
export BUILD
export DOCKERVERSION

MAJOR=$(head -1 version)
MINOR=$(date +"%Y")
PATCH=$(date +"%-m")
BUILD=$(date +"%-d")

DOCKERVERSION="$MAJOR.$MINOR.$PATCH.$BUILD"