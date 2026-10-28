#!/bin/bash
# Test suite for the customer .env passthrough (docs/adr/0002-customer-env-file-reaches-containers.md)
# Usage: bash test/deploy-env-passthrough.sh
# Needs the docker compose CLI (no daemon: only `docker compose config` runs).

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

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  if [[ "$haystack" != *"$needle"* ]]; then ok "$label"
  else fail "$label — expected not to find: $needle"; fi
}

MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT

CUSTOMER_ENV="$MOCK_DIR/customer.env"
export SECRET_KEY_BASE=test-key
cat > "$CUSTOMER_ENV" <<'ENV'
COMPOSE_PROJECT_NAME=passthrough-test
BE_SUBDOMAIN=be
FE_SUBDOMAIN=fe
BASE_DOMAIN=example.com
APP_SPECIFIC_SWITCH=off
RAILS_ENV=development
ENV

service_env() {
  docker compose -f docker/docker-compose.yml config --format json 2>/dev/null \
    | python3 -c "import json,sys; e=json.load(sys.stdin)['services']['$1']['environment']; print('\n'.join(f'{k}={v}' for k,v in e.items()))"
}

echo "compose: customer env file reaches backend and worker"
for service in backend worker; do
  env_out=$(CUSTOMER_ENV_FILE="$CUSTOMER_ENV" IMAGE_TAG_BACKEND=img service_env "$service")
  assert_contains "$env_out" "APP_SPECIFIC_SWITCH=off" "$service gets a variable only the customer env file defines"
  assert_contains "$env_out" "RAILS_ENV=production" "$service keeps x-vars' RAILS_ENV over the customer env file"
done

echo "compose: works unchanged without a customer env file"
if env_out=$(env -u CUSTOMER_ENV_FILE IMAGE_TAG_BACKEND=img bash -c "$(declare -f service_env); service_env backend"); then
  ok "config succeeds without CUSTOMER_ENV_FILE"
  assert_not_contains "$env_out" "APP_SPECIFIC_SWITCH" "no customer variable leaks in"
else
  fail "config fails without CUSTOMER_ENV_FILE"
fi

echo "compose: refuses to start without SECRET_KEY_BASE"
if env -u SECRET_KEY_BASE CUSTOMER_ENV_FILE="$CUSTOMER_ENV" IMAGE_TAG_BACKEND=img \
    docker compose -f docker/docker-compose.yml config > /dev/null 2>&1; then
  fail "config fails without SECRET_KEY_BASE"
else
  ok "config fails without SECRET_KEY_BASE"
fi

echo "docker-deploy.sh: passes each customer env file to compose"
DEPLOY_DIR="$MOCK_DIR/app"
mkdir -p "$DEPLOY_DIR/vendor/deploytargets/provider"
echo "1.2.3" > "$DEPLOY_DIR/version"
echo "ssh://host.example.com:22" > "$DEPLOY_DIR/vendor/deploytargets/provider/docker_host"
cp "$CUSTOMER_ENV" "$DEPLOY_DIR/vendor/deploytargets/provider/customer.env"
deploy_out=$(cd "$DEPLOY_DIR" && DRY_RUN=1 CI_REGISTRY_IMAGE=registry/app bash "$OLDPWD/scripts/docker-deploy.sh" 2>&1)
assert_contains "$deploy_out" "export CUSTOMER_ENV_FILE=provider/customer.env" "compose up runs with CUSTOMER_ENV_FILE set"
assert_contains "$deploy_out" "--env-file provider/customer.env" "compose interpolation still reads the same file"
assert_contains "$deploy_out" "docker/installation-secrets.sh" "the secrets script is copied to the host"
assert_contains "$deploy_out" 'SECRETS_FILE=$(bash installation-secrets.sh provider/customer.env) || exit 3' "the host's secrets file is prepared before compose up"
assert_contains "$deploy_out" 'set -a; . "$SECRETS_FILE"; set +a' "its keys are exported, so they win over the env file's"

echo "compose: the previous SECRET_KEY_BASE reaches backend and worker"
for service in backend worker; do
  env_out=$(CUSTOMER_ENV_FILE="$CUSTOMER_ENV" IMAGE_TAG_BACKEND=img SECRET_KEY_BASE_PREVIOUS=old \
    SECRET_KEY_BASE_PREVIOUS_EXPIRES_AT=2026-10-28T12:00:00Z service_env "$service")
  assert_contains "$env_out" "SECRET_KEY_BASE_PREVIOUS=old" "$service gets SECRET_KEY_BASE_PREVIOUS"
  assert_contains "$env_out" "SECRET_KEY_BASE_PREVIOUS_EXPIRES_AT=2026-10-28T12:00:00Z" "$service gets its expiry"
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
