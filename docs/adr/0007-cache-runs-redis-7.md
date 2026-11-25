# The deploy compose's cache runs Redis 7

**Status**: accepted

The `cache` service in `docker/docker-compose.yml` ran `eqalpha/keydb`, a Redis 6 fork with no release since 2023. Every deployed Thecore app uses `cache` for Sidekiq (jobs, sidekiq-scheduler, sidekiq-failures) and Action Cable (`REDIS_URL: redis://cache`), while the devcontainers and the tests already ran `redis:7-bookworm`: production ran a different server from the one the code was developed and tested on, and an unmaintained one that image scans flag (GitHub #24).

**Decision**: `cache` runs `redis:7-bookworm`, the devcontainers' image, with `command: redis-server`; healthcheck (`redis-cli ping`), `restart` and logging unchanged. No app code changes: Sidekiq 7.3 and Action Cable support Redis 7. Shipped together with the Rails 8.1 `:3` image (Odoo #6092 on Bancolini's GitLab).

## Consequences

- Nothing to migrate. `cache` declares no volume, but the `redis` image (like KeyDB's) has an anonymous `VOLUME /data` with RDB snapshots on, and `docker compose up -d` reuses it when it recreates the container: on Labs dev (2026-11-25) Redis 7.4 loaded KeyDB's last snapshot (RDB 6.3.4, 460 keys) and the queue survived. Draining the Sidekiq queue first (stop `backend`, let `worker` empty it) is still the safe order, because a write after the last snapshot is lost, and `down -v` or `up -V` drops the volume.
- `redis:7-bookworm` resolves to 7.4, dual-licensed RSALv2/SSPLv1 (7.2 was the last BSD-3 release). Running it inside an app's own stack is allowed; offering Redis itself as a service is not. A customer whose policy needs an OSI licence pins `redis:7.2-bookworm` (end of life) or uses Valkey.
- Installations whose compose is written by hand on the host (IMAS prod, already on Redis 7) don't receive this file and are changed by hand, if at all.
- release/4 drops Redis altogether (Solid Queue and Solid Cable in the app's Postgres).
- Covered by `test/cache-image.sh`.
