# The installation's `.env` file reaches `backend` and `worker`

**Status**: accepted

`docker-deploy.sh` runs `docker compose --env-file vendor/deploytargets/<provider>/<customer>.env`. `--env-file` only feeds the compose file's own `${...}` interpolation, and `backend`/`worker` only received the variables listed in `x-vars`. A variable one app needs on one installation, such as MyTask's `GAMMA_INTEGRATION=disabled` on a Labs test installation that must not reach the customer's LAN (MyTask backend ADR 0031), could only reach the container by being added to `x-vars`. That would put one app's, or one customer's, variable in the compose file every thecore app is deployed with.

**Decision**: `docker-deploy.sh` exports `CUSTOMER_ENV_FILE=<provider>/<customer>.env` before `docker compose up`, and `backend`/`worker` declare `env_file: ${CUSTOMER_ENV_FILE:-/dev/null}`. Every variable in the installation's `.env` file now reaches the containers. `environment:` (`x-vars`) takes precedence over `env_file`, so the fixed values (`RAILS_ENV`, `DATABASE_URL`, `REDIS_URL`, …) cannot be overridden from an installation's file.

## Consequences

- The `/dev/null` fallback keeps the compose file working when it is used without the deploy script, and avoids `env_file`'s `required: false`, which needs Docker Compose 2.24 or later on every deploy host.
- Variables only meant for interpolation (`BE_SUBDOMAIN`, `BASE_DOMAIN`, …) now also appear in the containers' environment. They are harmless there, and `SECRET_KEY_BASE`/`ADMIN_PASSWORD` were already passed through `x-vars`.
- Like every compose change, this reaches an installation on its next redeploy, once the image carrying it is published.
- Covered by `test/deploy-env-passthrough.sh`.
