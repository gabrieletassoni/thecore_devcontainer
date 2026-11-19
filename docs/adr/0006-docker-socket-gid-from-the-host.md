# Give the devcontainer user the host's Docker socket group

**Status**: accepted

On 2026-11-19, inside the PJM devcontainer, every `docker` command as `vscode` failed with:

```
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
```

The app container bind-mounts the host's `/var/run/docker.sock`. A bind mount keeps the host's numeric owner and group, so the socket showed up as `root:973`. `vscode` is in the image's `docker` group, but that group's id is fixed when the image is built (996 in `vscode-devcontainers-thecore:3`), and it only matches a host whose own `docker` group happens to have the same id. Docker worked only through `sudo`.

**Decision**: `.devcontainer/docker-socket-gid.sh`, run by `devcontainer.json`'s `initializeCommand` after `heal-stale-containers.sh`. It runs on the host, reads the socket's group id (`stat -L -c %g`) and writes `DOCKER_SOCKET_GID=<gid>` to `.devcontainer/.env`. Compose reads that `.env` from the compose file's directory, and the app service has:

```yaml
group_add:
  - "${DOCKER_SOCKET_GID:-996}"
```

`group_add` takes a numeric id, so no group with that id needs to exist in the image. Without `.env` (no socket on the host, an older checkout) compose falls back to 996, the image's own `docker` group, which is the previous behaviour. The script always exits 0, so it never stops VS Code from opening the folder. `.env` is gitignored: it is different on every host.

Like `heal-stale-containers.sh` (ADR 0005), this is the canonical copy: every Thecore app and the scaffolding sources carry the same file, and `test/docker-socket-gid.sh` tests it. Edit it here and copy it everywhere.

## Considered options

- **Change the group id inside the container** (`groupmod -g <gid> docker` in `postCreateCommand` / `postStartCommand`): rejected. Group membership is read when a process starts, and the VS Code server and its terminals may already be running, so it takes effect only after another restart. It also fails when the gid is already taken by another group in the image.
- **`chmod 666` the socket** (on the host or in the container): rejected. It gives every user and every container on the host root-equivalent access to the Docker daemon.
- **Bake the gid into the image**: rejected. The gid differs from host to host.
- **Keep using `sudo docker`**: what was done until 2026-11-19. It works, but every tool that calls `docker` as the user (the VS Code Docker extension, scripts, agents) fails first.

## Consequences

- `group_add` is applied when the container is created. After the host's gid changes (Docker reinstalled), the container must be rebuilt; VS Code's `--no-recreate` start keeps the old group.
- On Docker Desktop the host socket is a symlink to a socket inside the VM, and the gid the container sees may differ from what `stat -L` reports on the host. The fallback then still applies, as before this change.
