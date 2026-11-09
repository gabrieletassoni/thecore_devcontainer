#!/bin/bash
# Test suite for scripts/thecore-app-dir.sh (the app folder ~/.bashrc points APPBIN,
# BUNDLE_APP_CONFIG and the prompt at)
# Usage: bash test/thecore-app-dir.sh
# No docker daemon needed: the /workspaces tree is a fake in a temp dir, passed
# through THECORE_WORKSPACES_DIR. Also checks that Dockerfile.dev's .bashrc uses it
# and hardcodes no app folder.

set -euo pipefail
cd "$(dirname "$0")/.."

SCRIPT="$PWD/scripts/thecore-app-dir.sh"
PASS=0; FAIL=0

ok() { echo "  ok: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Fresh fake /workspaces for one case.
setup() {
  rm -rf "$WORK/workspaces"
  mkdir -p "$WORK/workspaces"
}

# An app (a folder with a Gemfile) at /workspaces/$1.
app() {
  mkdir -p "$WORK/workspaces/$1"
  touch "$WORK/workspaces/$1/Gemfile"
}

# $1: label, $2: expected folder relative to the fake /workspaces.
assert_app_dir() {
  local out rc=0
  out=$(cd / && THECORE_WORKSPACES_DIR="$WORK/workspaces" bash "$SCRIPT" 2>&1) || rc=$?
  [ "$rc" -eq 0 ] || { fail "$1 (exit $rc)"; return; }
  [ "$out" = "$WORK/workspaces/$2" ] && ok "$1" || fail "$1 — got: '$out'"
}

echo "thecore-app-dir.sh"

# ── the two layouts ───────────────────────────────────────────────────────────
setup; app app
assert_app_dir "finds an app mounted at /workspaces/app (thecore samples)" app

setup; app project/backend
assert_app_dir "finds an app mounted at /workspaces/project/backend (extension scaffold)" project/backend

# ── lookup order: same as thecore-motd.sh ─────────────────────────────────────
setup; app app; app project/backend
assert_app_dir "prefers /workspaces/*/ over /workspaces/*/*/" app

setup; app project/backend; mkdir -p "$WORK/workspaces/project/backend/vendor/submodules/x"
touch "$WORK/workspaces/project/backend/vendor/submodules/x/Gemfile"
assert_app_dir "ignores Gemfiles deeper than /workspaces/*/*/" project/backend

# ── nothing mounted yet: the extension's default ──────────────────────────────
setup
assert_app_dir "falls back to /workspaces/project/backend when no Gemfile is found" project/backend

# ── Dockerfile.dev's .bashrc uses it ──────────────────────────────────────────
BASHRC_LINES=$(grep '>> ~/.bashrc' Dockerfile.dev)
if [[ "$BASHRC_LINES" == *'thecore-app-dir.sh'* ]]; then ok ".bashrc resolves the app folder with thecore-app-dir.sh"
else fail ".bashrc does not call thecore-app-dir.sh"; fi
for var in APPBIN BUNDLE_APP_CONFIG PS1; do
  line=$(grep "export $var=" <<<"$BASHRC_LINES" || true)
  if [ -n "$line" ] && [[ "$line" != *"/workspaces/"* ]]; then ok "$var hardcodes no app folder"
  else fail "$var hardcodes an app folder (or is missing): '$line'"; fi
done

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
