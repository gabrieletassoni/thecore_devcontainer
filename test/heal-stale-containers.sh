#!/bin/bash
# Test suite for .devcontainer/heal-stale-containers.sh
# Usage: bash test/heal-stale-containers.sh
# Needs a real Docker daemon: the bug it covers (a compose network deleted
# while the project's containers were stopped) only exists in the daemon.
# Every project it creates is named heal-test-*, and removed on exit.
# TEST_IMAGE overrides the image (default: redis:7-bookworm, already pulled
# by every devcontainer of the stack, so the test needs no network).

set -euo pipefail
cd "$(dirname "$0")/.."

SCRIPT="$PWD/.devcontainer/heal-stale-containers.sh"
IMAGE="${TEST_IMAGE:-redis:7-bookworm}"
PASS=0; FAIL=0

ok() { echo "  ok: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

WORK=$(mktemp -d)
# Every project is named heal-test-<case>-$$: cleanup finds them by that suffix
# (make_project runs in a $(...) subshell, so it can't record them in a variable).
cleanup() {
  # Best effort: a grep matching nothing must not stop the rest of the cleanup.
  set +e
  local p
  for p in $(docker ps -a --format '{{.Label "com.docker.compose.project"}}' | grep -E "^heal-test-.*-$$\$" | sort -u); do
    docker rm -f $(docker ps -aq --filter "label=com.docker.compose.project=$p") >/dev/null 2>&1
  done
  docker volume ls -q | grep -E "^heal-test-.*-$$_data\$" | xargs -r docker volume rm >/dev/null 2>&1
  docker network ls --format '{{.Name}}' | grep -E "^heal-test-.*-$$_default\$" | xargs -r docker network rm >/dev/null 2>&1
  rm -rf "$WORK"
}
trap cleanup EXIT

# A compose project shaped like a devcontainer: the "app" service carries the
# devcontainer.local_folder label VS Code puts on the primary container, "db"
# holds a named volume, both sit on the project's default network.
# Prints the workspace folder.
make_project() {
  local p="$1"
  local ws="$WORK/$p/workspace"
  mkdir -p "$ws"
  cat > "$WORK/$p/compose.yml" <<EOF
services:
  app:
    image: $IMAGE
    command: sleep infinity
    labels:
      devcontainer.local_folder: "$ws"
  db:
    image: $IMAGE
    command: sleep infinity
    volumes:
      - data:/data
volumes:
  data:
EOF
  docker compose -p "$p" -f "$WORK/$p/compose.yml" up -d >/dev/null 2>&1
  echo "$ws"
}

stop_project() { docker compose -p "$1" -f "$WORK/$1/compose.yml" stop -t 0 >/dev/null 2>&1; }

# What a pruned network / reset daemon network store leaves behind.
delete_network() { docker network rm "${1}_default" >/dev/null 2>&1; }

container_count() { docker ps -aq --filter "label=com.docker.compose.project=$1" | wc -l; }

volume_exists() { docker volume inspect "${1}_data" >/dev/null 2>&1; }

# Runs the script on a workspace folder; prints nothing, returns its exit code
# (callers use `|| rc=$?` or `|| true`, so set -e never stops the suite on it).
heal() { bash "$SCRIPT" "$1" >/dev/null 2>&1; }

echo "heal-stale-containers.sh"

# ── stale network ─────────────────────────────────────────────────────────────
P="heal-test-stale-$$"
WS=$(make_project "$P")
stop_project "$P"
delete_network "$P"
rc=0; heal "$WS" || rc=$?
[ "$rc" -eq 0 ] && ok "exits 0 after healing" || fail "exits 0 after healing (got $rc)"
[ "$(container_count "$P")" -eq 0 ] && ok "removes every container of a project whose network is gone" \
  || fail "removes every container of a project whose network is gone ($(container_count "$P") left)"
volume_exists "$P" && ok "keeps the project's volumes" || fail "keeps the project's volumes"

# ── healthy stopped project ───────────────────────────────────────────────────
P="heal-test-stopped-$$"
WS=$(make_project "$P")
stop_project "$P"
heal "$WS" || true
[ "$(container_count "$P")" -eq 2 ] && ok "leaves a stopped project whose network exists alone" \
  || fail "leaves a stopped project whose network exists alone ($(container_count "$P") left)"

# ── running project (a second VS Code window on the same folder) ──────────────
P="heal-test-running-$$"
WS=$(make_project "$P")
heal "$WS" || true
[ "$(docker ps -q --filter "label=com.docker.compose.project=$P" | wc -l)" -eq 2 ] \
  && ok "leaves a running project alone" || fail "leaves a running project alone"

# ── another folder's stale project ────────────────────────────────────────────
P="heal-test-other-$$"
make_project "$P" >/dev/null
stop_project "$P"
delete_network "$P"
mkdir -p "$WORK/unrelated"
heal "$WORK/unrelated" || true
[ "$(container_count "$P")" -eq 2 ] && ok "never touches another folder's project" \
  || fail "never touches another folder's project ($(container_count "$P") left)"

# ── nothing to do ─────────────────────────────────────────────────────────────
rc=0; heal "$WORK/unrelated" || rc=$?
[ "$rc" -eq 0 ] && ok "exits 0 when the folder has no containers" \
  || fail "exits 0 when the folder has no containers (got $rc)"

rc=0; DOCKER_HOST=unix:///nonexistent.sock heal "$WORK/unrelated" || rc=$?
[ "$rc" -eq 0 ] && ok "exits 0 when the docker daemon is unreachable, so VS Code reports the real error" \
  || fail "exits 0 when the docker daemon is unreachable (got $rc)"

# ── wiring ────────────────────────────────────────────────────────────────────
# VS Code runs initializeCommand on the host with the workspace folder as cwd,
# before `docker compose up`: the only hook early enough to heal.
init=$(grep '"initializeCommand"' .devcontainer/devcontainer.json || true)
[[ "$init" == *"bash .devcontainer/heal-stale-containers.sh '\${localWorkspaceFolder}'"* ]] \
  && ok "devcontainer.json's initializeCommand runs it on the workspace folder" \
  || fail "devcontainer.json's initializeCommand runs it on the workspace folder (got: $init)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
