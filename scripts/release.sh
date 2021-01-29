#!/bin/bash

# Trap failures to get also the line number of the failure
set -eE -o functrace
failure() {
  local lineno=$1
  local msg=$2
  echo "Failed at $lineno: $msg"
}
trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

push.sh
CURRENTVERSION=$(git describe --tags "$(git rev-list --tags --max-count=1)")
if [ -z "$CURRENTVERSION" ]
then
    git tag 0.0.1
    CURRENTVERSION=0.0.1
fi
echo "Currently this repository is at version $CURRENTVERSION"

select T in "Major" "Minor" "Patch"
do
  echo "Selected ${T}"
  case $T in
      Major ) 
          SWITCH="-M"
          break
          ;;
      Minor ) 
          SWITCH="-m"
          break
          ;;
      Patch ) 
          SWITCH="-p"
          break
          ;;
  esac
done

echo "SWTICH: $SWITCH"

DOCKERVERSION=$(increment_version.sh $SWITCH $CURRENTVERSION)
echo "New Version: $DOCKERVERSION"
git tag "$DOCKERVERSION"
git push --tags

exit 0