#!/bin/bash
# Test suite for the deploy compose's cache service (GitHub #24: KeyDB replaced by Redis 7)
# Usage: bash test/cache-image.sh
# Reads the repository files only: no docker daemon needed.

set -euo pipefail
cd "$(dirname "$0")/.."

PASS=0; FAIL=0

ok() { echo "  ok: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then ok "$label"
  else fail "$label — expected: '$expected', got: '$actual'"; fi
}

# Prints the value of the first key named KEY, at any depth, inside one service of a compose file.
service_key() {
  local file="$1" service="$2" key="$3"
  awk -v svc="  $service:" -v key="$key:" '
    $0 == svc { inside = 1; next }
    inside && /^  [^ ]/ { inside = 0 }
    inside { line = $0; sub(/^ +/, "", line)
             if (index(line, key) == 1) { sub(/^[^:]+: */, "", line); print line; exit } }
  ' "$file"
}

# ── cache runs the same Redis 7 the devcontainers run ─────────────────────────
echo "cache service (docker/docker-compose.yml)"

assert_eq "$(service_key docker/docker-compose.yml cache image)" "redis:7-bookworm" \
  "cache image is redis:7-bookworm"
assert_eq "$(service_key docker/docker-compose.yml cache command)" "redis-server" \
  "cache command is redis-server"
assert_eq "$(service_key docker/docker-compose.yml cache test)" '"redis-cli ping"' \
  "cache healthcheck still pings with redis-cli"

# ── KeyDB is gone from the repository ─────────────────────────────────────────
echo "No KeyDB left"

# This suite names it on purpose, and ADRs record what was replaced, so both are left out of the
# search. --untracked also sees new files;
# outside a git checkout the search can't run, which must fail rather than pass.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  mentions=$(git grep -n -i --untracked keydb -- . ':!test/cache-image.sh' ':!docs/adr' ':!submodules' || true)
  assert_eq "$mentions" "" "no file outside the ADRs mentions KeyDB"
else
  fail "no file mentions KeyDB — not a git checkout, cannot search"
fi

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
