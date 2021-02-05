#!/bin/bash

# Trap failures to get also the line number of the failure
set -eE -o functrace
failure() {
  local lineno=$1
  local msg=$2
  echo "Failed at $lineno: $msg"
}
trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

git add . -A
if [ "$1" ]
then
  git commit -a -m "$1"
else
  git commit -a
fi