#!/bin/bash -e

git add . -A
if [ "$1" ]
then
  git commit -a -m "$1"
else
  git commit -a
fi