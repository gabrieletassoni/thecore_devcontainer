# Raise `nofile` ulimit on `backend`/`worker` containers

**Status**: accepted

No file descriptor limit was ever configured anywhere in this pipeline — no `Dockerfile` `RUN ulimit`, no `ulimits:` stanza in `docker/docker-compose.yml`, no daemon-level override. Every deployed container therefore ran on Docker's own bare-metal default (soft limit 1024), which is what a UAT `worker` container actually hit after ~44 hours of uptime: a slow, still-unidentified file-descriptor leak (traced to eventfds behind Sidekiq's Redis fetch loop, root mechanism not pinned down) exhausted the limit and crashed the process with a `SystemStackError` inside `tiny_tds`'s native connect path, once the OS refused it a socket. We chose not to block this fix on finding the leak's exact root cause: raising the ceiling is safe and independently worthwhile regardless of what eventually causes any given leak.

We added a `ulimits: { nofile: { soft: 65536, hard: 1048576 } }` block to both the `backend` and `worker` services in `docker/docker-compose.yml` — not a `RUN ulimit` in a `Dockerfile`, which only affects that build-time layer and has no effect on the running container. Both services got it, not just `worker`: they share the same image and the same Ruby/gem dependency graph (including whatever library is actually behind the leak), so the same failure mode is possible on `backend` even though it hasn't been observed there yet.

## Considered Options

- **`RUN ulimit -n 65536` in the Dockerfile.** Rejected: this only constrains the build-time `RUN` layer's own process; it has no effect on `docker run`/`docker compose up` containers, which always start with the engine's default unless the compose file (or `docker run --ulimit`) says otherwise.
- **Docker daemon-level `default-ulimits` in `daemon.json` on each host.** Rejected: that config lives on the deploy host, entirely outside this repo's version control and outside what `docker-deploy.sh` provisions — it would need to be set by hand per host and would silently drift from whatever this repo assumes.

## Consequences

- This travels the same way every other change to `docker/docker-compose.yml` does: baked into the image (`Dockerfile.common`: `COPY docker /etc/thecore/docker`), rsynced to the remote host by `scripts/docker-deploy.sh`, and picked up automatically the next time an installation bumps its own `version` file and its CI redeploys — not retroactively applied to containers already running.
- This is a ceiling increase only; it does not fix whatever is actually leaking descriptors. If the leak continues, it will now take far longer to resurface, which trades a hard, loud crash for a much longer runway — worth pairing with monitoring (e.g. alert on `nofile` usage) rather than treating this as a resolution of the underlying leak.
