#!/bin/bash
# Test suite for .devcontainer/docker-socket-gid.sh
# Usage: bash test/docker-socket-gid.sh
# Needs the docker CLI with compose (for `docker compose config`), not a daemon.
# Runs a copy of the script in a temp dir, so the real .devcontainer/.env is
# never touched.

set -euo pipefail
cd "$(dirname "$0")/.."

PASS=0; FAIL=0
ok() { echo "  ok: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/.devcontainer"
cp .devcontainer/docker-socket-gid.sh .devcontainer/docker-compose.yml "$WORK/.devcontainer/"
SCRIPT="$WORK/.devcontainer/docker-socket-gid.sh"
ENV_FILE="$WORK/.devcontainer/.env"

echo "docker-socket-gid.sh"

# A stand-in for the socket: the script only reads its group id
touch "$WORK/socket"
want=$(stat -c %g "$WORK/socket")

rc=0; bash "$SCRIPT" "$WORK/socket" || rc=$?
[ "$rc" -eq 0 ] && [ "$(cat "$ENV_FILE" 2>/dev/null)" = "DOCKER_SOCKET_GID=$want" ] \
  && ok "writes the socket's gid to .devcontainer/.env" \
  || fail "writes the socket's gid to .devcontainer/.env (rc $rc, got: $(cat "$ENV_FILE" 2>/dev/null))"

# A symlinked socket (Docker Desktop, rootless setups) reports its target's gid
ln -s "$WORK/socket" "$WORK/socket-link"
rm -f "$ENV_FILE"; bash "$SCRIPT" "$WORK/socket-link" || true
[ "$(cat "$ENV_FILE" 2>/dev/null)" = "DOCKER_SOCKET_GID=$want" ] \
  && ok "follows a symlinked socket to its target" \
  || fail "follows a symlinked socket to its target (got: $(cat "$ENV_FILE" 2>/dev/null))"

rm -f "$ENV_FILE"
rc=0; bash "$SCRIPT" "$WORK/missing.sock" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 0 ] && [ ! -e "$ENV_FILE" ] \
  && ok "exits 0 and writes nothing when there is no socket, so VS Code still opens the folder" \
  || fail "exits 0 and writes nothing when there is no socket (rc $rc)"

# ── compose ───────────────────────────────────────────────────────────────────
echo "DOCKER_SOCKET_GID=4242" > "$ENV_FILE"
cfg=$(docker compose -f "$WORK/.devcontainer/docker-compose.yml" config 2>/dev/null || true)
grep -A1 "group_add:" <<<"$cfg" | grep -q '"4242"' \
  && ok "compose adds the gid from .devcontainer/.env to the app container" \
  || fail "compose adds the gid from .devcontainer/.env to the app container"

rm -f "$ENV_FILE"
cfg=$(docker compose -f "$WORK/.devcontainer/docker-compose.yml" config 2>/dev/null || true)
grep -A1 "group_add:" <<<"$cfg" | grep -q '"996"' \
  && ok "compose falls back to the image's docker group (996) without .env" \
  || fail "compose falls back to the image's docker group (996) without .env"

# ── wiring ────────────────────────────────────────────────────────────────────
# initializeCommand runs on the host before `docker compose up`: the socket
# there carries the gid the container will see.
init=$(grep '"initializeCommand"' .devcontainer/devcontainer.json || true)
[[ "$init" == *"bash .devcontainer/docker-socket-gid.sh"* ]] \
  && ok "devcontainer.json's initializeCommand runs it" \
  || fail "devcontainer.json's initializeCommand runs it (got: $init)"

git check-ignore -q .devcontainer/.env \
  && ok ".devcontainer/.env is gitignored (it is per host)" \
  || fail ".devcontainer/.env is gitignored (it is per host)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
