#!/bin/bash
# Test suite for bin/build-image
# Usage: bash test/build-image.sh
# Mocks docker so no daemon is required.

set -euo pipefail
cd "$(dirname "$0")/.."

PASS=0; FAIL=0

ok() { echo "  ok: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if [[ "$haystack" == *"$needle"* ]]; then ok "$label"
  else fail "$label — expected to find: $needle"; fi
}

assert_exits_nonzero() {
  local label="$1"; shift
  if "$@" 2>/dev/null; then fail "$label — expected non-zero exit"
  else ok "$label"; fi
}

# ── mock environment ──────────────────────────────────────────────────────────
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT

DOCKER_LOG="$MOCK_DIR/docker.log"

# mock docker: records subcommand + args to log, always succeeds
cat > "$MOCK_DIR/docker" << 'EOF'
#!/bin/bash
echo "$@" >> "$DOCKER_LOG"
EOF
chmod +x "$MOCK_DIR/docker"

export PATH="$MOCK_DIR:$PATH"
export DOCKER_LOG

# ── tests ─────────────────────────────────────────────────────────────────────
echo "=== bin/build-image ==="

# RED: file doesn't exist yet — these tests define the interface
echo ""; echo "-- error handling --"

assert_exits_nonzero "exits non-zero with no args" \
  bash bin/build-image

assert_exits_nonzero "exits non-zero when dockerfile missing" \
  bash bin/build-image my-image Dockerfile.nonexistent

assert_exits_nonzero "exits non-zero when hook path missing" \
  bash bin/build-image thecore-common Dockerfile.common bin/hooks/nonexistent.sh

echo ""; echo "-- docker build calls --"

rm -f "$DOCKER_LOG"
bash bin/build-image thecore-common Dockerfile.common 2>/dev/null
build_call=$(grep "^build " "$DOCKER_LOG" | head -1)

assert_contains "$build_call" "-f Dockerfile.common"           "correct dockerfile"
assert_contains "$build_call" "--build-arg THECORE_VERSION=3"  "version build-arg injected"
assert_contains "$build_call" "-t gabrieletassoni/thecore-common:latest"  "tag :latest"
assert_contains "$build_call" "-t gabrieletassoni/thecore-common:3"       "tag :MAJOR"

echo ""; echo "-- DOCKERUSER override --"

rm -f "$DOCKER_LOG"
DOCKERUSER=myorg bash bin/build-image thecore-common Dockerfile.common 2>/dev/null
build_call=$(grep "^build " "$DOCKER_LOG" | head -1)
assert_contains "$build_call" "-t myorg/thecore-common:latest" "DOCKERUSER env var respected"

echo ""; echo "-- push calls --"

rm -f "$DOCKER_LOG"
bash bin/build-image thecore-common Dockerfile.common 2>/dev/null
push_calls=$(grep "^push " "$DOCKER_LOG" || echo "")
assert_contains "$push_calls" "gabrieletassoni/thecore-common:latest"  "pushes :latest"
assert_contains "$push_calls" "gabrieletassoni/thecore-common:3"       "pushes :MAJOR"

echo ""; echo "-- pre-build hook --"

HOOK="$MOCK_DIR/test-hook.sh"
HOOK_MARKER="$MOCK_DIR/hook-ran"
cat > "$HOOK" << HOOKEOF
#!/bin/bash
touch "$HOOK_MARKER"
HOOKEOF

rm -f "$DOCKER_LOG" "$HOOK_MARKER"
bash bin/build-image thecore-common Dockerfile.common "$HOOK" 2>/dev/null

if [[ -f "$HOOK_MARKER" ]]; then ok "pre-build hook was sourced"
else fail "pre-build hook was not sourced"; fi

build_call=$(grep "^build " "$DOCKER_LOG" | head -1)
assert_contains "$build_call" "-f Dockerfile.common" "build ran after hook"

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
