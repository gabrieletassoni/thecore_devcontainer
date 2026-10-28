# `SECRET_KEY_BASE` lives on the Docker host, not in git

**Status**: accepted

Every installation's `SECRET_KEY_BASE` was a line of its `vendor/deploytargets/<provider>/<customer>.env`, committed in the app's repository. It signs the API's JWTs and Rails' cookies, so anyone who can read the repository can forge an admin session on that installation (MyTask backend, Odoo #5836).

**Decision**: `docker-deploy.sh` copies `docker/installation-secrets.sh` to the host and runs it before `docker compose up`. The script keeps `/root/persistence/<COMPOSE_PROJECT_NAME>/secrets.env` (mode `0600`, next to the installation's database, never in a mounted directory) and the deploy exports its values. A value exported in the shell wins over `--env-file` in compose interpolation, so the host's key is the one the containers get.

- **First deploy with this script**: the file doesn't exist yet. It adopts the key already in use: the env file's `SECRET_KEY_BASE`, else the running `backend` container's, else a new random one (a new installation). Nothing changes for an installation that doesn't ask for more, so every thecore app can take this image without logging its users out.
- **Rotation**: setting `SECRET_KEY_BASE_ROTATION=<any token>` in the env file (not a secret) asks for one. When the token differs from the one the file last applied, a new key is generated and the old one is kept as `SECRET_KEY_BASE_PREVIOUS`, with `SECRET_KEY_BASE_PREVIOUS_EXPIRES_AT` 60 minutes later (`SECRET_KEY_BASE_PREVIOUS_WINDOW_MINUTES`). `x-vars` passes both to `backend`/`worker`. To rotate again, change the token.
- Once a deploy finds the previous key expired, it removes it from the file.

## Consequences

- After the first deploy, `SECRET_KEY_BASE` must be removed from the env file. It is ignored from then on, and the deploy log warns while it's still there.
- The previous key is meant for apps that accept it only until its expiry: model_driven_api >= 3.13.0 does so for JWTs, so app users stay logged in (their token is renewed with the new key on their next request). With an older model_driven_api, a rotation logs everyone out once. Cookies are never rotated: admins of the web UI log in again.
- The key exists only on the host. Losing `/root/persistence/<COMPOSE_PROJECT_NAME>` loses the database too; a lost `secrets.env` alone means a new key and one more login for everyone.
- Hand-written compose files (deployed without this script) are untouched and keep their own `SECRET_KEY_BASE`.
- Covered by `test/installation-secrets.sh` and `test/deploy-env-passthrough.sh`.
