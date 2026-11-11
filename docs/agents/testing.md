# Testing

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (how to run the bash test suites, one line per suite). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

### Testing

Each file under `test/` is a standalone bash suite; CI doesn't run them, so run them by hand before pushing. Only `heal-stale-containers.sh` needs a running docker daemon:

```bash
bash test/build-image.sh            # bin/build-image tagging, build-arg, push, hooks (docker mocked)
bash test/deploy-env-passthrough.sh # customer .env reaches backend/worker (needs the docker compose CLI)
bash test/installation-secrets.sh   # host secrets.env: adopt, rotate, expire (docker mocked)
bash test/version-pins.sh           # Ruby patch pinned in Dockerfile.common, Rails >= 7.2.4 in Dockerfile.dev
bash test/thecore-app-dir.sh        # scripts/thecore-app-dir.sh finds the app under /workspaces/app or /workspaces/project/backend; .bashrc hardcodes neither
bash test/thecore-motd.sh           # scripts/thecore-motd.sh finds the scaffold marker under /workspaces/app and /workspaces/project/backend
bash test/gem-compile.sh            # scripts/gem-compile.sh pushes the built gem to rubygems.org or to GITLAB_GEM_REPO_TARGET (gem mocked)
bash test/heal-stale-containers.sh  # .devcontainer/heal-stale-containers.sh against real compose projects named heal-test-* (needs docker, ~5s)
```
