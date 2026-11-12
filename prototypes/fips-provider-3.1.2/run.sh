#!/bin/bash -e
# PROTOTYPE (Odoo 5886). One command: bash prototypes/fips-provider-3.1.2/run.sh <path-to-mytask-backend>
# (needs BUNDLE_GEMS__BANCOLINI__COM exported). Builds the FIPS image and an app image on top of it,
# starts Postgres (TLS, SCRAM + one md5 user), SQL Server 2022 and Samba on a scratch network, runs
# probe.rb, boots the server and runs the test suite. Everything is named fips-*; `run.sh --down` cleans up.
HERE="$(cd "$(dirname "$0")" && pwd)"
DOCKER="${DOCKER:-docker}"
NET=fips-net
PG_PW=probe-pg-pw
MSSQL_PW='Probe-Mssql-pw1'

if [ "$1" = "--down" ]; then
  $DOCKER rm -f fips-pg fips-mssql fips-smb fips-app 2>/dev/null || true
  $DOCKER network rm $NET 2>/dev/null || true
  exit 0
fi
APP_SRC="${1:?path to the mytask backend}"
WORK="${FIPS_WORK:-/tmp/fips-prototype}"
mkdir -p "$WORK"

start=$(date +%s)
$DOCKER build -t thecore-fips-prototype "$HERE" > "$WORK/build.log" 2>&1
echo "BUILD_SECONDS=$(( $(date +%s) - start ))"
$DOCKER image inspect thecore-fips-prototype --format 'IMAGE_SIZE={{.Size}}'

$DOCKER network create $NET >/dev/null 2>&1 || true
$DOCKER rm -f fips-pg fips-mssql fips-smb fips-app >/dev/null 2>&1 || true
$DOCKER run -d --name fips-pg --network $NET -e POSTGRES_PASSWORD=$PG_PW postgres:17-trixie bash -c '
  openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj /CN=fips-pg -keyout /tmp/k.pem -out /tmp/c.pem 2>/dev/null
  chown postgres /tmp/k.pem /tmp/c.pem && chmod 600 /tmp/k.pem
  exec docker-entrypoint.sh postgres -c ssl=on -c ssl_cert_file=/tmp/c.pem -c ssl_key_file=/tmp/k.pem' >/dev/null
$DOCKER run -d --name fips-mssql --network $NET -e ACCEPT_EULA=Y -e "MSSQL_SA_PASSWORD=$MSSQL_PW" \
  mcr.microsoft.com/mssql/server:2022-latest >/dev/null
$DOCKER run -d --name fips-smb --network $NET debian:trixie bash -c '
  apt-get update -qq && apt-get install -y -qq samba >/dev/null
  mkdir -p /share && echo hello > /share/hello.txt && useradd -M probe
  printf "probe-pw\nprobe-pw\n" | smbpasswd -s -a probe
  printf "[global]\nserver min protocol = SMB3\n[share]\npath = /share\nread only = no\nvalid users = probe\n" > /etc/samba/smb.conf
  exec smbd --foreground --no-process-group --debug-stdout' >/dev/null

# Scratch copy of the app: the real checkout is never touched.
rsync -a --delete --exclude .git --exclude node_modules --exclude tmp --exclude log --exclude storage \
  --exclude 'vendor/submodules' --exclude 'vendor/external' --exclude 'vendor/bundle' --exclude .bundle \
  "$APP_SRC/" "$WORK/app/"
sed -i -E "s/^gem 'pg', '~> 1.1'.*/gem 'pg', '~> 1.1', force_ruby_platform: true/; s/^gem 'tiny_tds', '~> 3.3'.*/gem 'tiny_tds', '~> 3.3', force_ruby_platform: true/" "$WORK/app/Gemfile"
cp "$HERE/probe.rb" "$WORK/app/probe.rb"
start=$(date +%s)
$DOCKER build -t thecore-fips-prototype-app -f "$HERE/app.Dockerfile" --secret id=bundle,env=BUNDLE_GEMS__BANCOLINI__COM \
  "$WORK/app" > "$WORK/app-build.log" 2>&1 || { tail -30 "$WORK/app-build.log"; exit 1; }
echo "APP_BUILD_SECONDS=$(( $(date +%s) - start ))"

until $DOCKER exec fips-pg pg_isready -U postgres -h 127.0.0.1 >/dev/null 2>&1; do sleep 1; done
$DOCKER exec fips-pg psql -U postgres -qc "SET password_encryption = 'md5'; CREATE ROLE probe_md5 LOGIN PASSWORD 'md5pw';" >/dev/null
$DOCKER exec fips-pg bash -c "sed -i '1i host all probe_md5 all md5' \$PGDATA/pg_hba.conf && psql -U postgres -qc 'SELECT pg_reload_conf()'" >/dev/null

APP_ENV=(-e "DATABASE_URL=postgres://postgres:$PG_PW@fips-pg:5432/mytask_imas_dev?sslmode=require"
  -e "PROBE_PG_URL=postgres://postgres:$PG_PW@fips-pg:5432/postgres?sslmode=require"
  -e "PROBE_PG_MD5_URL=postgres://probe_md5:md5pw@fips-pg:5432/postgres?sslmode=require"
  -e "PROBE_MSSQL_PASSWORD=$MSSQL_PW" -e COMPOSE_PROJECT_NAME=fips -e RAILS_ENV=development
  -e SECRET_KEY_BASE=probe-secret-key-base-0123456789abcdef0123456789abcdef0123456789abcdef)
RUN=($DOCKER run --rm --network $NET "${APP_ENV[@]}" thecore-fips-prototype-app)

"${RUN[@]}" bash -c 'bin/rails db:prepare >/dev/null 2>&1; bin/rails runner probe.rb' 2>&1 | tee "$WORK/probe.txt"

$DOCKER run -d --name fips-app --network $NET "${APP_ENV[@]}" thecore-fips-prototype-app \
  bash -c 'bin/rails db:prepare >/dev/null 2>&1; bin/rails server -b 0.0.0.0 -p 3000' >/dev/null
sleep 40
$DOCKER run --rm --network $NET curlimages/curl -s -o /dev/null -w 'BOOT GET /admin -> %{http_code}\n' http://fips-app:3000/admin | tee -a "$WORK/probe.txt"
$DOCKER logs fips-app > "$WORK/server.log" 2>&1

"${RUN[@]}" bash -c 'RAILS_ENV=test bin/rails db:prepare >/dev/null 2>&1; RAILS_ENV=test bin/rails test 2>&1' > "$WORK/test.txt" || true
tail -5 "$WORK/test.txt"
echo "results in $WORK"
