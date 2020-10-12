#/bin/bash -e

DOCKERVERSION=$(git describe --tags $(git rev-list --tags --max-count=1))
DOCKERUSER=gabrieletassoni
DOCKERTAG=$DOCKERUSER/vscode-devcontainers-thecore:$DOCKERVERSION

echo "Login to docker hub"
docker login -u $DOCKERUSER
docker build -t $DOCKERTAG .
docker push $DOCKERTAG
