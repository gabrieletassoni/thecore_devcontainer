#!/bin/bash -e

if [ "$#" -ne 1 ]
then
    echo "ERROR! The first argument must exists and it has to be the version"
    exit 1
fi

# /^\d+\.\d+\.\d+(-(test|dev|stage)){0,1}$/gm
echo "COMMIT TAG: $1"
VERSION=$1
# Version must have the form of a semver
# ^\d+\.\d+\.\d+(-(test|dev|stage)){0,1}$
# if ! [[ $VERSION =~ ^[0-9]+(\.[0-9]+){2,3}(-(test|dev|stage)){0,1}$ ]] 
# then
#     echo "ERROR! The VERSION $VERSION is not in semver format"
#     exit 3
# fi
# in a string like 1.2.3-dev:
# - SEMVER = 1.2.3
# - ENVIRONMENT = dev
# in a string like 1.2.3
# - SEMVER == ENVIRONMENT == VERSION == 1.2.3
SEMVER=${VERSION%%-*}
ENVIRONMENT=${VERSION##*-}

if ! [[ $SEMVER =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] 
then
    echo "ERROR! The VERSION $VERSION is not in semver format"
    exit 3
fi

if [[ $SEMVER == $ENVIRONMENT && $SEMVER == $VERSION && $VERSION == $ENVIRONMENT ]]
then
    # Sono in production
    HOSTFILE="docker_host"
else
    # Sono in uno degli env di preprod
    HOSTFILE="docker_${ENVIRONMENT}_host"
fi

echo "HOSTFILE: $HOSTFILE"

if ! [ -d installers ]
then
    echo "ERROR! This script must be run from the directory containing installers folder."
    exit 2
fi

cd installers
for PROVIDER in *
do 
if [ -f "$PROVIDER/$HOSTFILE" ]
then
    echo "$PROVIDER has a $HOSTFILE file, let's see if it also has customers"
    export DOCKER_HOST="$(cat "$PROVIDER/$HOSTFILE")"
    export DOCKER_HOST_DOMAIN="$(echo $DOCKER_HOST | cut -d'/' -f3 | cut -d':' -f1)"
    export DOCKER_HOST_PORT="$(echo $DOCKER_HOST | cut -d'/' -f3 | cut -d':' -f2)"
    ssh $DOCKER_HOST_DOMAIN -p $DOCKER_HOST_PORT "
        docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY; 
        mkdir -p /tmp/installers; 
        exit"
    rsync -arvz -e "ssh -p $DOCKER_HOST_PORT" --progress --delete docker-compose.yml $PROVIDER ${DOCKER_HOST_DOMAIN}:/tmp/installers/
    for CUSTOMER in $PROVIDER/*.env
    do
    echo "  - found $CUSTOMER doing the remote up thing on $DOCKER_HOST"
    ssh $DOCKER_HOST_DOMAIN -p $DOCKER_HOST_PORT " 
        export IMAGE_TAG_HELPDESK_SIDEKIQ=$IMAGE_TAG_HELPDESK_SIDEKIQ; 
        export IMAGE_TAG_HELPDESK=$IMAGE_TAG_HELPDESK; 
        export IMAGE_TAG_BACKEND=$IMAGE_TAG_BACKEND; 
        export IMAGE_TAG_BACKEND_SIDEKIQ=$IMAGE_TAG_BACKEND_SIDEKIQ; 
        cd /tmp/installers
        docker-compose --env-file $CUSTOMER pull; 
        docker-compose --env-file $CUSTOMER up -d --remove-orphans --no-build;
        docker system prune -f; docker logout $CI_REGISTRY; 
        exit"
    done
fi
done
    