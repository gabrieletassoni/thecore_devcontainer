# Production stack and deployment

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (production services, runtime environment, secrets, docker-deploy.sh). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

### Production Services (docker-compose.yml)

Four services form the production stack:
- **db**: PostgreSQL 15, data persisted at `/root/persistence/$COMPOSE_PROJECT_NAME/db`
- **cache**: KeyDB (Redis-compatible), no persistence
- **backend**: Rails app — entrypoint runs `db:create`, `db:migrate`, `thecore:db:seed`, `assets:clobber`, `assets:precompile`, then `rails s` (all steps unconditional — convention over configuration)
- **worker**: Sidekiq, waits for backend health before starting

`backend` and `worker` both set `ulimits: nofile: {soft: 65536, hard: 1048576}` — Docker's bare default (1024 soft) is otherwise silently in effect for every container in this stack, which is easy to hit over long uptimes (see `docs/adr/0001-container-nofile-ulimits.md`). A `Dockerfile` `RUN ulimit` would **not** work here — that only affects the build-time layer, not the running container — so this must live in the compose file, which propagates to installations via the same `docker-deploy.sh` rsync-on-redeploy path as every other change here (not retroactively, to containers already running).

Key environment variables required at runtime:
- `SECRET_KEY_BASE` — Rails secret key, from the Docker host's `secrets.env`, never the `.env` file (see below)
- `APP_NAME` — Application name
- `COMPOSE_PROJECT_NAME` — Used for volume namespacing
- `BE_SUBDOMAIN`, `FE_SUBDOMAIN`, `BASE_DOMAIN` — Domain configuration
- `IMAGE_TAG_BACKEND` — Docker image to deploy

`SECRET_KEY_BASE` does not belong in the installation's `.env` file: `docker-deploy.sh` takes it from the Docker host's `/root/persistence/${COMPOSE_PROJECT_NAME}/secrets.env`, which `installation-secrets.sh` creates on the first deploy by adopting the key in use (the env file's, else the running backend's, else a new one). Set `SECRET_KEY_BASE_ROTATION=<token>` in the `.env` file to rotate it: the old key stays valid for JWTs as `SECRET_KEY_BASE_PREVIOUS` for 60 minutes (model_driven_api >= 3.13.0). See `docs/adr/0004-secret-key-base-lives-on-the-docker-host.md`.

Optional: `ADMIN_PASSWORD` — the first admin's password. If `ADMIN_PASSWORD` is unset or empty, the seed (thecore_auth_commons >= 3.6.2) creates the first admin, `admin@BASE_DOMAIN`, with a random password written to `/root/persistence/${COMPOSE_PROJECT_NAME}/storage/admin_initial_password` on the Docker host (mode `0600`, never logged; or `docker compose exec backend cat storage/admin_initial_password`). Change it after the first login and delete the file. The admin is created only on a database without one, so setting or changing `ADMIN_PASSWORD` later has no effect. Older backends fall back to the fixed `Change#1`, so keep setting it for them. `docker-compose.yml` passes it as `${ADMIN_PASSWORD:-}`, so an unset value is no compose warning.

`backend` and `worker` also load the installation's own `.env` file as `env_file: ${CUSTOMER_ENV_FILE:-/dev/null}` (`docker-deploy.sh` exports `CUSTOMER_ENV_FILE`), so an app can read a variable of its own, set per installation in `vendor/deploytargets/<provider>/<customer>.env`, without adding it to `x-vars`. `x-vars` still wins on any name both define. See `docs/adr/0002-customer-env-file-reaches-containers.md`, tested by `test/deploy-env-passthrough.sh`.

### Deployment Script (`scripts/docker-deploy.sh`)

This script handles multi-customer, multi-provider deployments:
- Reads deploy targets from `vendor/deploytargets/PROVIDER/`
- Each provider directory can have `docker_host` (production) or `docker_TARGETENV_host` (staging, etc.)
- Each `*.env` file in a provider directory represents one customer deployment
- Connects via SSH (`remote_exec`) and rsyncs (`remote_rsync`) compose files and `installation-secrets.sh`, exports the host's `secrets.env` (ADR 0004), then runs `docker compose up -d` with `CUSTOMER_ENV_FILE` set to that customer's `.env` (passed to the containers, see Production Services above)
- Set `TARGETENV` environment variable to target non-production environments
- Set `DRY_RUN=1` to print all SSH and rsync commands without executing (useful for CI previews or local verification)
