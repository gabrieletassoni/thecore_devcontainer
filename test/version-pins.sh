#!/bin/bash
# Test suite for the Ruby and Rails versions in the images (docs/adr/0003-ruby-and-rails-versions-pinned.md)
# Usage: bash test/version-pins.sh
# Reads the Dockerfiles only: no docker daemon needed.

set -euo pipefail
cd "$(dirname "$0")/.."

PASS=0; FAIL=0

ok() { echo "  ok: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_matches() {
  local haystack="$1" regex="$2" label="$3"
  if [[ "$haystack" =~ $regex ]]; then ok "$label"
  else fail "$label — got: $haystack"; fi
}

# ── Ruby: thecore-common's base image names a full X.Y.Z patch ────────────────
echo "Ruby pin (Dockerfile.common)"

from_line=$(grep -m1 '^FROM ' Dockerfile.common || true)
assert_matches "$from_line" '^FROM ruby:3\.3\.[0-9]+-bookworm$' "base image pins the Ruby 3.3 patch"

# ── Rails: the dev image installs at least 7.2.4, never a 7.3 ─────────────────
echo "Rails pin (Dockerfile.dev)"

rails_install=$(grep -o "rails:'[^']*'" Dockerfile.dev || true)
assert_matches "$rails_install" "^rails:'~> 7\.2\.([4-9]|[1-9][0-9])'$" "rails minimum is 7.2.4 or a later 7.2 patch"

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
