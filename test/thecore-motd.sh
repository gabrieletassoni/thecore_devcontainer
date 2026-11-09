#!/bin/bash
# Test suite for scripts/thecore-motd.sh (the "scaffold older than this image" warning)
# Usage: bash test/thecore-motd.sh
# No docker daemon needed: the image's version file and the /workspaces tree are
# fakes in a temp dir, passed through THECORE_IMAGE_VERSION_FILE and
# THECORE_WORKSPACES_DIR. Needs dpkg (Debian/Ubuntu host), as the image does.

set -euo pipefail
cd "$(dirname "$0")/.."

SCRIPT="$PWD/scripts/thecore-motd.sh"
PASS=0; FAIL=0

ok() { echo "  ok: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Fresh fake image + workspaces for one case. $1: image version ("" = no file).
setup() {
  rm -rf "$WORK/case"
  mkdir -p "$WORK/case/etc" "$WORK/case/workspaces"
  [ -z "$1" ] || echo "$1" > "$WORK/case/etc/thecore-version.txt"
}

# Writes the marker under an app mounted at /workspaces/$1. $2: scaffold version.
marker() {
  mkdir -p "$WORK/case/workspaces/$1/.devcontainer"
  echo "$2" > "$WORK/case/workspaces/$1/.devcontainer/.thecore-template-version"
}

# Runs the motd from / (the login shell's cwd is not the app's), prints its output.
motd() {
  (cd / && THECORE_IMAGE_VERSION_FILE="$WORK/case/etc/thecore-version.txt" \
    THECORE_WORKSPACES_DIR="$WORK/case/workspaces" bash "$SCRIPT" 2>&1)
}

assert_warns() {
  local out rc=0
  out=$(motd) || rc=$?
  [ "$rc" -eq 0 ] || { fail "$1 (exit $rc)"; return; }
  if [[ "$out" == *"v$2"*"v$3"* ]]; then ok "$1"
  else fail "$1 — got: '$out'"; fi
}

assert_silent() {
  local out rc=0
  out=$(motd) || rc=$?
  [ "$rc" -eq 0 ] || { fail "$1 (exit $rc)"; return; }
  [ -z "$out" ] && ok "$1" || fail "$1 — got: '$out'"
}

echo "thecore-motd.sh"

# ── older marker: warns, under either layout ──────────────────────────────────
setup 3.2.0; marker app 3.1.9
assert_warns "warns for an older marker under /workspaces/app" 3.1.9 3.2.0

setup 3.2.0; marker project/backend 3.1.9
assert_warns "warns for an older marker under /workspaces/project/backend" 3.1.9 3.2.0

setup 3.10.0; marker app 3.9.0
assert_warns "compares versions numerically, not as strings" 3.9.0 3.10.0

# ── current or newer marker: silent ───────────────────────────────────────────
setup 3.2.0; marker app 3.2.0
assert_silent "silent for a current marker under /workspaces/app"

setup 3.2.0; marker project/backend 3.2.0
assert_silent "silent for a current marker under /workspaces/project/backend"

setup 3.2.0; marker project/backend 3.3.0
assert_silent "silent for a marker newer than the image"

# ── missing files: silent ─────────────────────────────────────────────────────
setup 3.2.0
assert_silent "silent when no workspace has a marker"

setup 3.2.0; mkdir -p "$WORK/case/workspaces/project/backend/.devcontainer"
assert_silent "silent for a scaffold without a marker (legacy)"

setup ""; marker project/backend 3.1.9
assert_silent "silent when the image has no version file (non-dev image)"

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
