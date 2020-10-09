#/bin/bash -e

DOCKERVERSION=2.0.0
DOCKERUSER=gabrieletassoni
DOCKERTAG=$DOCKERUSER/vscode-devcontainers-thecore:$DOCKERVERSION

echo "Login to docker hub"
docker login -u $DOCKERUSER
docker build -t $DOCKERTAG .
docker push $DOCKERTAG