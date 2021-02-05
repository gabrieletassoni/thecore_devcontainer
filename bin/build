#!/bin/bash
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

DOCKERVERSION=$(bin/increment_version.sh $SWITCH $CURRENTVERSION)
echo "New Version: $DOCKERVERSION"
git add . -A
git commit -a -m "New Version $DOCKERVERSION"
git tag "$DOCKERVERSION"
git push
git push --tags
DOCKERUSER=gabrieletassoni
DOCKERTAG=$DOCKERUSER/vscode-devcontainers-thecore:$DOCKERVERSION

docker build -t "$DOCKERTAG" .
export DOCKERTAG=$DOCKERTAG
exit 0