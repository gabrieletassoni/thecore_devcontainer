#!/bin/bash
# Test suite for the Trivy fail gate and the nightly build it scans (docs/agents/security-scanning.md)
# Usage: bash test/security-scan.sh
# Reads the workflows and .trivyignore.yaml only: no docker daemon, no network.

set -euo pipefail
cd "$(dirname "$0")/.."

PASS=0; FAIL=0

ok() { echo "  ok: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

BUILD=.github/workflows/main.yml
SCAN=.github/workflows/trivy.yml
IGNORE=.trivyignore.yaml

# The block of one workflow step, from its "- name:" line to the next step.
step_block() {
  awk -v name="$2" '
    /^      - name: / { on = (index($0, "- name: " name) > 0) }
    on { print }
  ' "$1"
}

# ── The images are rebuilt every night, so fixed Debian packages land before the gate ──
echo "Nightly build ($BUILD)"

build_cron=$(grep -oE 'cron: "[^"]+"' "$BUILD" || true)
if [[ "$build_cron" =~ ^cron:\ \"[0-9]+\ [0-9]+\ \*\ \*\ \*\"$ ]]; then ok "build runs every day ($build_cron)"
else fail "build runs every day — got: '${build_cron}'"; fi

# ── The fail gate scans the image that nightly build just pushed ──────────────
echo "Fail gate ($SCAN)"

if grep -qE '^\s+schedule:' "$SCAN"; then fail "scan has no cron of its own (it would race the build)"
else ok "scan has no cron of its own (it would race the build)"; fi

gate=$(step_block "$SCAN" "Fail the nightly run on findings")
if [[ -n "$gate" ]]; then ok "fail gate step exists"; else fail "fail gate step exists"; fi

if grep -qF "github.event.workflow_run.event == 'schedule'" <<<"$gate"; then ok "gate runs only after the scheduled build"
else fail "gate runs only after the scheduled build — got: $(grep -E '^\s+if:' <<<"$gate" || echo none)"; fi

if grep -qE "trivyignores: $IGNORE\$" <<<"$gate"; then ok "gate reads $IGNORE"
else fail "gate reads $IGNORE"; fi

sarif=$(step_block "$SCAN" "Scan for the Security tab")
if grep -q 'trivyignores' <<<"$sarif"; then fail "Security tab scan ignores nothing (accepted CVEs stay visible)"
else ok "Security tab scan ignores nothing (accepted CVEs stay visible)"; fi

# ── Every accepted CVE expires and says why ───────────────────────────────────
echo "Accepted findings ($IGNORE)"

if [[ -f "$IGNORE" ]]; then
  ids=$(grep -cE '^\s+- id: ' "$IGNORE" || true)
  expiries=$(grep -cE '^\s+expired_at: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$IGNORE" || true)
  statements=$(grep -cE '^\s+statement: .+' "$IGNORE" || true)
  if [[ "$ids" -eq "$expiries" ]]; then ok "each of the $ids entries has an expired_at date"
  else fail "each entry has an expired_at date — $ids ids, $expiries dates"; fi
  if [[ "$ids" -eq "$statements" ]]; then ok "each of the $ids entries has a statement"
  else fail "each entry has a statement — $ids ids, $statements statements"; fi

  # Expiry at most 92 days ahead of the date the entry was written is not checkable
  # offline; cap it at one quarter from today instead, so nothing is accepted for long.
  limit=$(date -u -d '+92 days' +%Y-%m-%d)
  while read -r d; do
    if [[ "$d" > "$limit" ]]; then fail "expired_at $d is within 92 days (by $limit)"
    else ok "expired_at $d is within 92 days"; fi
  done < <(grep -oE 'expired_at: [0-9-]+' "$IGNORE" | awk '{print $2}')
else
  fail "$IGNORE exists"
fi

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
