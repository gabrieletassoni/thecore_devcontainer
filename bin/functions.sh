#!/bin/bash -e

function yes_or_no {
    while true; do
        read -p "$* [y/n]: " yn
        case $yn in
            [Yy]*) return 0  ;;  
            [Nn]*) echo "Aborted" ; return  1 ;;
        esac
    done
}

echo "$DOCKERTAG"
[[ -z "$DOCKERTAG" ]] && exit 1
if [[ -n "$GITHUB_WORKSPACE" ]] || yes_or_no "Would you like to push this image to the docker hub?"
then
    echo "Login to docker hub"
    # docker login
    docker push "$DOCKERTAG:$MAJOR"
    docker push "$DOCKERTAG:$DOCKERVERSION"
    docker push "$DOCKERTAG:latest"
else
    exit 0
fi
