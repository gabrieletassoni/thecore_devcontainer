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

# ── Rails: the dev image installs at least 8.1.4.1, never an 8.2 ──────────────
echo "Rails pin (Dockerfile.dev)"

# Rails gets its own `gem install` (RubyGems refuses --version with several gem names).
rails_install=$(grep -oE "gem install rails( -v '[^']*')+" Dockerfile.dev || true)
assert_matches "$rails_install" "^gem install rails -v '~> 8\.1\.[0-9]+' -v '>= 8\.1\.[0-9]+(\.[0-9]+)?'$" \
  "rails is ~> 8.1.x plus an exact minimum, never 8.2"

# The minimum never drops below the 8.1.4.1 security release (version order, not text order).
rails_min=$(grep -oE "rails( -v '[^']*')* -v '>= [0-9.]+'" Dockerfile.dev | grep -oE "[0-9.]+'$" | tr -d "'" || true)
lowest=$(printf '%s\n' "${rails_min:-0}" 8.1.4.1 | sort -V | head -1)
if [[ -n "$rails_min" && "$lowest" == "8.1.4.1" ]]; then ok "rails minimum ($rails_min) is 8.1.4.1 or later"
else fail "rails minimum is 8.1.4.1 or later — got: '${rails_min}'"; fi

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
