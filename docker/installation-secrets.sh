#!/bin/bash -e
# Keeps an installation's SECRET_KEY_BASE on the Docker host, never in git
# (docs/adr/0004-secret-key-base-lives-on-the-docker-host.md).
#
# Usage: installation-secrets.sh <customer.env>
# Prints the path of PERSISTENCE_ROOT/<COMPOSE_PROJECT_NAME>/secrets.env, which docker-deploy.sh
# sources before `docker compose up`. Never prints a key.
#
# - First deploy: adopts the key already in use (the env file's SECRET_KEY_BASE, else the running
#   backend's), else generates one. Nobody is logged out.
# - SECRET_KEY_BASE_ROTATION=<token> in the env file, different from the one last applied: a new key,
#   the old one kept as SECRET_KEY_BASE_PREVIOUS for SECRET_KEY_BASE_PREVIOUS_WINDOW_MINUTES (60).
# - An expired previous key is dropped.

ENV_FILE="$1"
ROOT="${PERSISTENCE_ROOT:-/root/persistence}"
WINDOW_MINUTES="${SECRET_KEY_BASE_PREVIOUS_WINDOW_MINUTES:-60}"

value_of() {
    sed -n "s/^$1=//p" "$2" | tail -n 1 | tr -d '\r' | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
}

new_key() {
    od -An -tx1 -N64 /dev/urandom | tr -d ' \n'
}

running_key() {
    local id
    id=$(docker ps -q --filter "label=com.docker.compose.project=$PROJECT" \
        --filter "label=com.docker.compose.service=backend" 2>/dev/null | head -n 1)
    [[ -n "$id" ]] || return 0
    docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$id" | sed -n 's/^SECRET_KEY_BASE=//p' | head -n 1
}

# write_secrets <current> [<previous> <expires_at>] — atomic, owner-only
write_secrets() {
    local tmp="$SECRETS.tmp"
    {
        echo "SECRET_KEY_BASE=$1"
        [[ -n "${2:-}" ]] && echo "SECRET_KEY_BASE_PREVIOUS=$2" && echo "SECRET_KEY_BASE_PREVIOUS_EXPIRES_AT=$3"
        [[ -n "$ROTATION_DONE" ]] && echo "SECRET_KEY_BASE_ROTATION=$ROTATION_DONE"
        true
    } > "$tmp"
    mv "$tmp" "$SECRETS"
}

PROJECT=$(value_of COMPOSE_PROJECT_NAME "$ENV_FILE")
if [[ -z "$PROJECT" ]]; then
    echo "ERROR! $ENV_FILE has no COMPOSE_PROJECT_NAME" >&2
    exit 1
fi

umask 077
mkdir -p "$ROOT/$PROJECT"
SECRETS="$ROOT/$PROJECT/secrets.env"
ENV_KEY=$(value_of SECRET_KEY_BASE "$ENV_FILE")

if [[ ! -f "$SECRETS" ]]; then
    ROTATION_DONE=""
    if [[ -n "$ENV_KEY" ]]; then
        echo "secrets: adopting the env file's SECRET_KEY_BASE into $SECRETS" >&2
        KEY="$ENV_KEY"
    else
        KEY=$(running_key)
        if [[ -n "$KEY" ]]; then
            echo "secrets: adopting the running backend's SECRET_KEY_BASE into $SECRETS" >&2
        else
            echo "secrets: generating a new SECRET_KEY_BASE in $SECRETS" >&2
            KEY=$(new_key)
        fi
    fi
    write_secrets "$KEY"
elif [[ -n "$ENV_KEY" ]]; then
    echo "secrets: WARNING $ENV_FILE still has SECRET_KEY_BASE; it is ignored, remove it from git" >&2
fi

CURRENT=$(value_of SECRET_KEY_BASE "$SECRETS")
PREVIOUS=$(value_of SECRET_KEY_BASE_PREVIOUS "$SECRETS")
EXPIRES_AT=$(value_of SECRET_KEY_BASE_PREVIOUS_EXPIRES_AT "$SECRETS")
ROTATION_DONE=$(value_of SECRET_KEY_BASE_ROTATION "$SECRETS")
ROTATION_REQUESTED=$(value_of SECRET_KEY_BASE_ROTATION "$ENV_FILE")

if [[ -n "$ROTATION_REQUESTED" && "$ROTATION_REQUESTED" != "$ROTATION_DONE" ]]; then
    echo "secrets: rotating SECRET_KEY_BASE ($ROTATION_REQUESTED), previous key accepted for $WINDOW_MINUTES minutes" >&2
    ROTATION_DONE="$ROTATION_REQUESTED"
    write_secrets "$(new_key)" "$CURRENT" "$(date -u -d "+$WINDOW_MINUTES minutes" +%Y-%m-%dT%H:%M:%SZ)"
elif [[ -n "$PREVIOUS" ]] && ! [[ $(date -u -d "$EXPIRES_AT" +%s 2>/dev/null || echo 0) -gt $(date -u +%s) ]]; then
    echo "secrets: dropping the expired previous SECRET_KEY_BASE" >&2
    write_secrets "$CURRENT"
fi

echo "$SECRETS"
