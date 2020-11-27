#/bin/bash -e

bin/build.sh
docker push $DOCKERTAG
