#!/bin/bash -e

MAJOR=2
MINOR=$(date +"%Y")
PATCH=$(date +"%-m")
BUILD=$(date +"%-d")

DOCKERVERSION="$MAJOR.$MINOR.$PATCH.$BUILD"