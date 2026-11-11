# Dev container

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (vscode-devcontainers-thecore shell setup, motd, healing containers left on a deleted network). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

### Dev Container (vscode-devcontainers-thecore)

The dev image runs as user `vscode` with passwordless sudo and Docker group membership. The `.bashrc` configuration sets `THECORE_APP_DIR` to the mounted app's folder, printed by `thecore-app-dir.sh`: the first folder with a `Gemfile` under `/workspaces/*/`, then `/workspaces/*/*/` (the same order `thecore-motd.sh` uses), so `/workspaces/app` for apps created from the thecore samples and `/workspaces/project/backend` for the extension's scaffold, falling back to the latter when none is mounted. Then:
- `APPBIN=$THECORE_APP_DIR/bin`
- `COMPOSE_PROJECT_NAME=thecore_test`
- `BUNDLE_APP_CONFIG=$THECORE_APP_DIR/.bundle`
- the prompt's version read from `$THECORE_APP_DIR/version`
- Gems installed into `vendor/bundle` inside the workspace

The working directory inside the container is `/workspaces/project`.

`.bashrc` also runs `thecore-motd.sh` on every new shell. It compares `/etc/thecore/thecore-version.txt` (the Thecore extension version baked into this image at build time, written alongside `build/thecore.vsix` by `bin/hooks/package-vscode-extension.sh`) against the `.devcontainer/.thecore-template-version` of the app mounted under `/workspaces/*/` or `/workspaces/*/*/` (so both `/workspaces/app`, the thecore samples' layout, and `/workspaces/project/backend`, the extension's, are found whatever the shell's cwd; stamped with the extension version by the "Thecore 3: Setup Devcontainer" command when it scaffolds `.devcontainer/`). If the scaffold predates the image, it prints a warning suggesting the user regenerate `.devcontainer/`. Silent no-op if either file is missing (legacy scaffolds, non-dev images, or projects not using this generator). Tested by `test/thecore-motd.sh`.

### Heal containers left on a deleted network

VS Code starts a compose devcontainer with `docker compose up --no-recreate`, so containers stopped while their network was deleted (a `docker network prune`, a Docker upgrade) failed every start with `network <id> not found`, reboots included. `.devcontainer/heal-stale-containers.sh`, run by `initializeCommand` on the host, removes that project's containers so compose recreates them; volumes are kept, and healthy, running or other folders' projects are left alone (`docs/adr/0005-heal-containers-left-on-a-deleted-network.md`). This is the canonical copy: every Thecore app carries the same file, as do `thecore_code_extension`'s `templates/setupDevContainer/` and `thecore`'s `samples/devcontainer/` (fetched by `thecore_generators`'s App template). Change it here, run `test/heal-stale-containers.sh`, then copy it to all of them.
