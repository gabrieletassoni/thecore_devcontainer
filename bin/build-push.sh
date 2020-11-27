#/bin/bash -e

bin/build.sh
echo "Login to docker hub"
docker login
[[ -n "$DOCKERTAG" ]] && docker push $DOCKERTAG

exit 0