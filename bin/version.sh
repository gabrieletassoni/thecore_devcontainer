#!/bin/bash -e

MAJOR=$(head -1 version)
MINOR=$(date +"%Y")
PATCH=$(date +"%-m")
BUILD=$(date +"%-d")

DOCKERVERSION="$MAJOR.$MINOR.$PATCH.$BUILD"