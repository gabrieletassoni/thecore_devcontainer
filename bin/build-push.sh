#/bin/bash -e

DOCKERVERSION=$(git describe --tags $(git rev-list --tags --max-count=1))
if [ -z "$DOCKERVERSION" ]
then
    echo -e "\n\e[1m\e[31mERROR! Please tag this repository, like: git tag 0.0.1\e[0m\e[0m"
    exit 1
fi
DOCKERUSER=gabrieletassoni
DOCKERTAG=$DOCKERUSER/vscode-devcontainers-thecore:$DOCKERVERSION

echo "Login to docker hub"
docker login
docker build -t $DOCKERTAG .
docker push $DOCKERTAG
