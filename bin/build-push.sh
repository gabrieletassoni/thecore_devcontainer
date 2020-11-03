#/bin/bash -e

CURRENTVERSION=$(git describe --tags $(git rev-list --tags --max-count=1))
if [ -z "$CURRENTVERSION" ]
then
    git tag 0.0.1
    CURRENTVERSION=0.0.1
fi
echo "Currently this repository is at version $CURRENTVERSION"

select T in "Major" "Minor" "Patch"
do
  echo "Selected ${T}"
  if ! [ -z "${T}" ]
  then
    TYPE="$T"
    break
  fi
done

case $T in
    Major ) 
        SWITCH="-M"
        ;;
    Minor ) 
        SWITCH="-m"
        ;;
    Patch ) 
        SWITCH="-p"
        ;;
esac

echo "SWTICH: $SWITCH"

DOCKERVERSION=$(bin/increment_version.sh $SWITCH $CURRENTVERSION)
echo "New Version: $DOCKERVERSION"
git add . -A
git commit -a -m "New Version $DOCKERVERSION"
git tag $DOCKERVERSION
DOCKERUSER=gabrieletassoni
DOCKERTAG=$DOCKERUSER/vscode-devcontainers-thecore:$DOCKERVERSION

echo "Login to docker hub"
docker login
docker build -t $DOCKERTAG .
docker push $DOCKERTAG
