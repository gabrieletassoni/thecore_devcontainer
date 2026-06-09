#!/bin/bash -e

echo "Getting current version"
VERSION=$(tr -d '\n' < version)

# Used to not have conflicting installations
UUID=$(cat /proc/sys/kernel/random/uuid)
TARGET_DIR="/tmp/installers/$UUID"

# remote_exec: run a command on a remote host via SSH, or print it when DRY_RUN=1.
# Two adapters justify this seam: SSH (production) and dry-run (testing/preview).
remote_exec() {
    local host="$1" port="$2" cmd="$3"
    if [[ "${DRY_RUN:-}" == "1" ]]; then
        echo "[DRY-RUN] ssh ${host}:${port} → ${cmd}"
    else
        ssh "$host" -p "$port" "$cmd"
    fi
}

remote_rsync() {
    local port="$1" src_files=("${@:2:$#-2}") dest="${*: -1}"
    if [[ "${DRY_RUN:-}" == "1" ]]; then
        echo "[DRY-RUN] rsync -e 'ssh -p ${port}' ${src_files[*]} ${dest}"
    else
        rsync -arvz -e "ssh -p $port" --progress --delete "${src_files[@]}" "$dest"
    fi
}

# Setup SSH trust (CI environment only — skipped when DRY_RUN=1)
if [[ "${DRY_RUN:-}" != "1" ]]; then
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    echo -e "Host *\n\tStrictHostKeyChecking no\n\tControlMaster auto\n\tControlPath ~/.ssh/socket-%C\n\tControlPersist 1\n\n" > ~/.ssh/config
    chmod 600 ~/.ssh/config
    echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
    chmod 600 ~/.ssh/id_rsa
fi

SEMVER=${VERSION%%-*}

if ! [[ $SEMVER =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
then
    echo "ERROR! The VERSION $VERSION is not in semver format"
    exit 3
fi

if [ -z "${TARGETENV}" ]
then
    # Sono in production
    HOSTFILE="docker_host"
else
    # Sono in uno degli env di preprod
    HOSTFILE="docker_${TARGETENV}_host"
fi

echo "HOSTFILE: $HOSTFILE"

DEPTARGETS="vendor/deploytargets"
if ! [ -d $DEPTARGETS ]
then
    echo "ERROR! This script must be run from the directory containing $DEPTARGETS folder."
    exit 2
fi

cd $DEPTARGETS
for PROVIDER in *
do
    if [ -f "$PROVIDER/$HOSTFILE" ]
    then
        echo "$PROVIDER has a $HOSTFILE file, let's see if it also has customers"
        DOCKER_HOST="$(cat "$PROVIDER/$HOSTFILE")"
        export DOCKER_HOST
        DOCKER_HOST_DOMAIN="$(echo "$DOCKER_HOST" | cut -d'/' -f3 | cut -d':' -f1)"
        export DOCKER_HOST_DOMAIN
        DOCKER_HOST_PORT="$(echo "$DOCKER_HOST" | cut -d'/' -f3 | cut -d':' -f2)"
        export DOCKER_HOST_PORT
        remote_exec "$DOCKER_HOST_DOMAIN" "$DOCKER_HOST_PORT" "
            docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY || exit 1
            mkdir -p $TARGET_DIR"
        remote_rsync "$DOCKER_HOST_PORT" \
            /etc/thecore/docker/docker-compose.yml \
            /etc/thecore/docker/docker-compose.net.yml \
            "$PROVIDER" \
            "${DOCKER_HOST_DOMAIN}:$TARGET_DIR"
        for CUSTOMER in "$PROVIDER"/*.env
        do
            echo "  - found $CUSTOMER doing the remote up thing on $DOCKER_HOST"
            if [[ -f "$PROVIDER"/image ]]
            then
                IMAGE_TAG_BACKEND=${CI_REGISTRY_IMAGE}/backend-$(head -c -1 "$PROVIDER"/image):$VERSION
            else
                IMAGE_TAG_BACKEND=${CI_REGISTRY_IMAGE}/backend:$VERSION
            fi
            export IMAGE_TAG_BACKEND
            remote_exec "$DOCKER_HOST_DOMAIN" "$DOCKER_HOST_PORT" "
                export IMAGE_TAG_BACKEND=$IMAGE_TAG_BACKEND
                cd $TARGET_DIR
                docker compose -f docker-compose.yml -f docker-compose.net.yml --env-file $CUSTOMER up -d --remove-orphans --no-build || exit 2
                docker system prune -f
                docker logout $CI_REGISTRY
                rm -rf $TARGET_DIR"
        done
    fi
done
