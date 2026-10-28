#!/bin/bash
# Test suite for docker/installation-secrets.sh (docs/adr/0004-secret-key-base-lives-on-the-docker-host.md)
# Usage: bash test/installation-secrets.sh
# Needs nothing but bash and GNU date: a fake `docker` stands in for the running backend container.

set -euo pipefail
cd "$(dirname "$0")/.."
SCRIPT="$PWD/docker/installation-secrets.sh"

PASS=0; FAIL=0

ok() { echo "  ok: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_eq() {
  if [[ "$1" == "$2" ]]; then ok "$3"; else fail "$3 — expected '$2', got '$1'"; fi
}

assert_ne() {
  if [[ "$1" != "$2" ]]; then ok "$3"; else fail "$3 — expected anything but '$2'"; fi
}

MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT

# Fake docker: `docker ps` finds a backend container only when RUNNING_KEY is set,
# `docker inspect` prints its environment.
mkdir -p "$MOCK_DIR/bin"
cat > "$MOCK_DIR/bin/docker" <<'SH'
#!/bin/bash
case "$1" in
  ps) [[ -n "${RUNNING_KEY:-}" ]] && echo "c0ffee" ;;
  inspect) printf 'PATH=/usr/bin\nSECRET_KEY_BASE=%s\n' "$RUNNING_KEY" ;;
esac
exit 0
SH
chmod +x "$MOCK_DIR/bin/docker"
export PATH="$MOCK_DIR/bin:$PATH"

case_n=0
# new_case <env file lines...>: a fresh persistence root and customer env file
new_case() {
  case_n=$((case_n + 1))
  export PERSISTENCE_ROOT="$MOCK_DIR/root$case_n"
  ENV_FILE="$MOCK_DIR/customer$case_n.env"
  printf '%s\n' "COMPOSE_PROJECT_NAME=app$case_n" "$@" > "$ENV_FILE"
  unset RUNNING_KEY
}

run() { bash "$SCRIPT" "$ENV_FILE" 2>/dev/null; }
secret() { sed -n "s/^$1=//p" "$PERSISTENCE_ROOT/app$case_n/secrets.env"; }

echo "first deploy adopts the key already in use"
new_case "SECRET_KEY_BASE=from-env-file"
export RUNNING_KEY=from-container
path=$(run)
assert_eq "$path" "$PERSISTENCE_ROOT/app$case_n/secrets.env" "prints the secrets file's path"
assert_eq "$(secret SECRET_KEY_BASE)" "from-env-file" "takes the env file's key, as the deploy did before"
assert_eq "$(secret SECRET_KEY_BASE_PREVIOUS)" "" "no previous key without a rotation request"
assert_eq "$(stat -c %a "$path")" "600" "the file is readable by its owner only"

new_case
export RUNNING_KEY=from-container
run > /dev/null
assert_eq "$(secret SECRET_KEY_BASE)" "from-container" "without one in the env file, takes the running backend's key"

new_case
run > /dev/null
key=$(secret SECRET_KEY_BASE)
assert_eq "${#key}" "128" "a new installation gets a fresh 64-byte hex key"

echo "later deploys keep the host's key"
new_case "SECRET_KEY_BASE=from-env-file"
run > /dev/null
sed -i 's/^SECRET_KEY_BASE=.*/SECRET_KEY_BASE=changed-in-git/' "$ENV_FILE"
run > /dev/null
assert_eq "$(secret SECRET_KEY_BASE)" "from-env-file" "a key in the env file no longer overrides the host's"

echo "a new SECRET_KEY_BASE_ROTATION token rotates the key once"
new_case "SECRET_KEY_BASE=leaked" "SECRET_KEY_BASE_ROTATION=2026-10-28"
before=$(date -u +%s)
run > /dev/null
assert_ne "$(secret SECRET_KEY_BASE)" "leaked" "a new current key"
assert_eq "$(secret SECRET_KEY_BASE_PREVIOUS)" "leaked" "the old key becomes the previous one"
expires=$(date -u -d "$(secret SECRET_KEY_BASE_PREVIOUS_EXPIRES_AT)" +%s)
window=$(( (expires - before) / 60 ))
assert_eq "$window" "60" "the previous key expires 60 minutes later"
rotated=$(secret SECRET_KEY_BASE)
run > /dev/null
assert_eq "$(secret SECRET_KEY_BASE)" "$rotated" "the same token does not rotate again"

echo "an expired previous key is dropped"
sed -i 's/^SECRET_KEY_BASE_PREVIOUS_EXPIRES_AT=.*/SECRET_KEY_BASE_PREVIOUS_EXPIRES_AT=2026-01-01T00:00:00Z/' \
  "$PERSISTENCE_ROOT/app$case_n/secrets.env"
run > /dev/null
assert_eq "$(secret SECRET_KEY_BASE_PREVIOUS)" "" "previous key removed"
assert_eq "$(secret SECRET_KEY_BASE_PREVIOUS_EXPIRES_AT)" "" "its expiry removed"
assert_eq "$(secret SECRET_KEY_BASE)" "$rotated" "current key kept"

echo "finds the running backend under compose's lowercase project label"
new_case
sed -i 's/^COMPOSE_PROJECT_NAME=.*/COMPOSE_PROJECT_NAME=MyApp/' "$ENV_FILE"
cat > "$MOCK_DIR/bin/docker" <<'SH'
#!/bin/bash
case "$1" in
  ps) [[ "$*" == *"com.docker.compose.project=myapp "* ]] && echo "c0ffee" ;;
  inspect) echo "SECRET_KEY_BASE=lowercase-label" ;;
esac
exit 0
SH
run > /dev/null
assert_eq "$(sed -n 's/^SECRET_KEY_BASE=//p' "$PERSISTENCE_ROOT/MyApp/secrets.env")" "lowercase-label" "adopts the key of project myapp"

echo "refuses values the deploy could not source safely"
new_case 'SECRET_KEY_BASE_ROTATION=2026 10 28'
if run > /dev/null; then fail "a rotation token with spaces fails the deploy"; else ok "a rotation token with spaces fails the deploy"; fi
new_case 'SECRET_KEY_BASE=abc$(touch pwned)'
if run > /dev/null; then fail "a key with shell syntax fails the deploy"; else ok "a key with shell syntax fails the deploy"; fi

echo "refuses an env file without COMPOSE_PROJECT_NAME"
new_case
sed -i '/^COMPOSE_PROJECT_NAME=/d' "$ENV_FILE"
if run > /dev/null; then fail "exits non-zero"; else ok "exits non-zero"; fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
