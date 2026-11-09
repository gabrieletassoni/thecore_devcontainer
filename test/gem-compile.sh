#!/bin/bash
# Test suite for scripts/gem-compile.sh
# Usage: bash test/gem-compile.sh
# Mocks gem, so nothing is built or published.

set -euo pipefail
cd "$(dirname "$0")/.."
SCRIPT="$PWD/scripts/gem-compile.sh"

PASS=0; FAIL=0
ok() { echo "  ok: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/atom"
cat > "$WORK/bin/gem" <<'MOCK'
#!/bin/bash
echo "$@" >> "$GEM_LOG"
[ "$1" = build ] && touch my_atom-3.0.0.gem
exit 0
MOCK
chmod +x "$WORK/bin/gem"
touch "$WORK/atom/my_atom.gemspec"
export GEM_LOG="$WORK/gem.log"

# Under set -e a failing run must not stop the suite: it shows up as a missing push below.
run() { (cd "$WORK/atom" && rm -f ./*.gem && : > "$GEM_LOG" && PATH="$WORK/bin:$PATH" bash "$SCRIPT" >/dev/null 2>&1) || true; }

echo "gem-compile.sh"

unset GITLAB_GEM_REPO_TARGET
run
push=$(grep '^push' "$GEM_LOG" || true)
[ "$push" = "push my_atom-3.0.0.gem" ] && ok "without GITLAB_GEM_REPO_TARGET pushes the built gem to rubygems.org" \
  || fail "without GITLAB_GEM_REPO_TARGET pushes the built gem to rubygems.org (got: $push)"

GITLAB_GEM_REPO_TARGET=https://gems.example.com/ run
push=$(grep '^push' "$GEM_LOG" || true)
[ "$push" = "push --host https://gems.example.com/ my_atom-3.0.0.gem" ] && ok "with GITLAB_GEM_REPO_TARGET pushes the built gem to that host" \
  || fail "with GITLAB_GEM_REPO_TARGET pushes the built gem to that host (got: $push)"

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
