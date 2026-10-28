# GLOSSARY.md — Thecore Backend DevContainer

Comprehensive project context for AI agent skills (grill-with-docs, to-spec, to-tickets, tdd).

---

## Purpose

This repository builds and publishes three Docker images that form the standard environment for **Thecore**-based Ruby on Rails applications. It contains no application code — only infrastructure, build tooling, runtime scripts, and a VS Code extension.

---

## Images Produced

| Image | Docker Hub Tag | Base | Purpose |
|---|---|---|---|
| `Dockerfile.common` | `gabrieletassoni/thecore-common` | `ruby:3.3.<patch>-bookworm` | Base system: Ruby 3.3 (patch pinned), APT packages, shared scripts |
| `Dockerfile.dev` | `gabrieletassoni/vscode-devcontainers-thecore` | `thecore-common` | Full dev environment: Docker-in-Docker, Rails tools, VS Code extension |
| `Dockerfile.deploy` | `gabrieletassoni/thecore` | `thecore-common` | Minimal production image: Rails server + Sidekiq |

Build order is always: **common → dev → deploy**.

---

## Repository Layout

```
thecore_devcontainer/
├── bin/
│   ├── build                  # Runs all three builds sequentially
│   ├── build-common           # Builds thecore-common
│   ├── build-for-dev          # Packages VS Code ext + builds dev image
│   ├── build-for-deploy       # Builds deploy image
│   ├── version.sh             # Exports $MAJOR, $DOCKERVERSION (sourced, not called)
│   ├── docker-push.sh         # Pushes $DOCKERTAG with all tags (sourced, not called)
│   └── increment_version.sh
├── scripts/                   # Copied into images at /usr/bin/
│   ├── app-compile.sh         # Builds application Docker image from within dev env
│   ├── docker-build.sh        # Docker build + push wrapper (used in CI pipelines)
│   ├── docker-deploy.sh       # Multi-customer SSH deploy via docker compose
│   └── gem-compile.sh         # Builds and pushes Ruby gems
├── docker/                    # Copied into images at /etc/thecore/docker/
│   ├── Dockerfile             # (unused; actual builds use root Dockerfiles)
│   ├── docker-compose.yml     # Production stack: db, cache, backend, worker
│   ├── docker-compose.net.yml # Adds nginx-proxy + Let's Encrypt
│   ├── docker-compose.build.yml
│   ├── entrypoint.sh          # Rails startup: db:create, migrate, [seed if SEED_ON_START=true], [assets unless compiled], server
│   └── entrypoint-sidekiq.sh  # Sidekiq worker startup
├── os/
│   ├── 02nocache              # Disables APT caching (copied into images)
│   └── 01_nodoc               # Skips doc installation via dpkg (copied into images)
├── submodules/
│   └── thecore_code_extension/  # VS Code extension (git submodule, branch release/3)
├── .devcontainer/             # VS Code devcontainer for working on this repo itself
│   ├── Dockerfile             # Docker-in-Docker setup
│   ├── devcontainer.json
│   └── library-scripts/
├── .github/workflows/main.yml # CI: push to release/3, weekly, or manual trigger
├── Dockerfile.common
├── Dockerfile.dev
├── Dockerfile.deploy
├── docs/adr/                  # Architecture decision records
├── test/                      # Shell test suites (bash test/<name>.sh)
├── version                    # Single line: current major version (e.g. "3")
└── README.md
```

---

## Versioning

Format: `MAJOR.YEAR.MONTH.DAY`

- `MAJOR` — read from the `version` file (currently `3`)
- Date components — computed at build time in `bin/version.sh`
- Example: `3.2026.6.9`

Each image is tagged `:latest`, `:MAJOR`, and `:MAJOR.YEAR.MONTH.DAY`.

`bin/version.sh` exports: `$MAJOR`, `$MINOR`, `$PATCH`, `$BUILD`, `$DOCKERVERSION`.

---

## Build System

### Entry Points

```bash
./bin/build              # All three images
./bin/build-common       # thecore-common only
./bin/build-for-dev      # dev image only (also packages VS Code extension)
./bin/build-for-deploy   # deploy image only
```

### Deep Module: `bin/build-image`

`bin/build-image IMAGE_NAME DOCKERFILE [PRE_BUILD_HOOK]` is the single build-and-push module. All three entry points delegate to it. It owns: DOCKERUSER, tagging strategy (`:latest`, `:MAJOR`, `:DOCKERVERSION`), build-arg injection, and push mechanics. Override `DOCKERUSER` via env var for forks.

### Conventions

- All build scripts use `#!/bin/bash -e` (exit on first error); the tests under `test/` use `#!/bin/bash` + `set -euo pipefail`.
- `bin/build-image` is the only caller of `bin/version.sh` and `bin/docker-push.sh`; individual build scripts no longer source these directly.
- Pre-build hooks live in `bin/hooks/`. Currently: `bin/hooks/package-vscode-extension.sh` (discovers VS Code extensions in `submodules/*/`, runs `vsce package`, outputs `build/thecore.vsix`).
- All `docker build` commands pass `--build-arg THECORE_VERSION="${MAJOR}"` (enforced inside `bin/build-image`).

---

## Scripts (copied into images at `/usr/bin/`)

### `docker-build.sh`
Builds and pushes a Docker image inside a CI pipeline (GitLab CI context):
- Reads `$CI_PROJECT_DIR`, `$IMAGE_TAG_BACKEND`, `$CI_REGISTRY*` variables.
- Takes `$1` = Dockerfile path, `$2` = version tag.
- Runs `docker build` with `--network=host`, `--no-cache`, `--pull`.
- Passes `--build-arg CUSTOMBUILDDIR=./vendor/custombuilds/<dirname>/` and `--build-arg CI_REGISTRY_IMAGE` and `--build-arg CI_COMMIT_TAG`.
- Logs in to `$CI_REGISTRY` and pushes.

### `app-compile.sh`
Run from inside a Thecore Rails app repo to build its application image:
- Reads version from a local `version` file.
- Sets `IMAGE_TAG_BACKEND=${CI_REGISTRY_IMAGE}/backend:$version`.
- Falls back to `/etc/thecore/docker/Dockerfile` if no `Dockerfile` present in `$CURDIR`.
- Delegates to `/usr/bin/docker-build.sh`.

### `docker-deploy.sh`
Multi-customer, multi-provider deployment via SSH:
- Reads deploy targets from `vendor/deploytargets/PROVIDER/`.
- Each provider directory contains a `docker_host` file (production) or `docker_${TARGETENV}_host` (staging, etc.).
- Each `*.env` file in a provider dir = one customer deployment.
- Optionally reads `vendor/deploytargets/PROVIDER/image` to build a custom `IMAGE_TAG_BACKEND`.
- Connects via SSH, rsyncs `docker-compose.yml` + `docker-compose.net.yml` + `installation-secrets.sh`, exports the host's `secrets.env` (ADR 0004), runs `docker compose up -d`.
- Set `$TARGETENV` to target non-production environments.
- Set `DRY_RUN=1` to print all SSH and rsync commands without executing them (useful for verifying deploy logic in CI preview or locally).

### `gem-compile.sh`
Builds and pushes a Ruby gem:
- Runs `gem build *.gemspec` + `gem push`.
- If `$GITLAB_GEM_REPO_TARGET` is set, pushes to that host instead of rubygems.org.
- Requires `$GEM_HOST_API_KEY` for private registries.

---

## Dockerfile Details

### `Dockerfile.common` (Base)
- From `ruby:3.3.<patch>-bookworm`, the patch pinned to the apps' `.ruby-version` (`docs/adr/0003-ruby-and-rails-versions-pinned.md`)
- Copies `os/` config files, `scripts/` → `/usr/bin/`, `docker/` → `/etc/thecore/docker/`
- Installs a large set of APT packages (see Dockerfile for full list): build tools, image processing (libvips, imagemagick), network tools, Git, SSH, etc.
- Sets `LC_ALL`, `LANG`, `LANGUAGE` to `en_US.UTF-8`
- Exposes port `3000`

### `Dockerfile.dev` (Dev Environment)
- From `gabrieletassoni/thecore-common:${THECORE_VERSION}`
- Installs Docker CE + Compose plugin (from official Docker APT repo)
- Installs: `git-flow`, `graphviz`, `python3-pip`
- Installs Ruby gems: `rails ~> 7.2.4` (minimum 7.2 patch, never 7.3; `docs/adr/0003-ruby-and-rails-versions-pinned.md`), `foreman`, `rufo`, `rubocop`, `ruby-lsp`
- Creates user `vscode` with passwordless sudo and docker group membership
- Configures `~/.bashrc` for the `vscode` user:
  - `APPBIN=/workspaces/project/backend/bin`
  - `COMPOSE_PROJECT_NAME=thecore_test`
  - `BUNDLE_APP_CONFIG=/workspaces/project/backend/.bundle`
  - Gems installed to `vendor/bundle` inside workspace
  - Prompt shows git branch + app version
- `WORKDIR /workspaces/project`
- Copies `build/thecore.vsix` → `/etc/thecore/`

### `Dockerfile.deploy` (Production)
- From `gabrieletassoni/thecore-common:${THECORE_VERSION}`
- Copies `docker/entrypoint*.sh` → `/bin/thecore_container/`
- `WORKDIR /app`
- Installs `bundler`, configures bundle path to `/app/vendor/bundle`, excludes `development` and `test` groups

---

## Production Stack (`docker/docker-compose.yml`)

Four services:

| Service | Image | Role |
|---|---|---|
| `db` | `postgres:15` | PostgreSQL, data at `/root/persistence/$COMPOSE_PROJECT_NAME/db` |
| `cache` | `eqalpha/keydb` | Redis-compatible cache, no persistence |
| `backend` | `$IMAGE_TAG_BACKEND` | Rails app (entrypoint: migrate, seed, assets, `rails s`) |
| `worker` | `$IMAGE_TAG_BACKEND` | Sidekiq (waits for backend health before starting) |

`docker-compose.net.yml` adds nginx-proxy + Let's Encrypt for TLS termination.

### Required Runtime Environment Variables

| Variable | Purpose |
|---|---|
| `SECRET_KEY_BASE` | Rails secret key, from the Docker host's `secrets.env` (ADR 0004) |
| `APP_NAME` | Application name |
| `COMPOSE_PROJECT_NAME` | Volume namespacing |
| `BE_SUBDOMAIN`, `FE_SUBDOMAIN`, `BASE_DOMAIN` | Domain config |
| `IMAGE_TAG_BACKEND` | Docker image to deploy |

`SECRET_KEY_BASE` does not belong in the installation's `.env` file: `docker-deploy.sh` takes it from the Docker host's `/root/persistence/${COMPOSE_PROJECT_NAME}/secrets.env`, which `installation-secrets.sh` creates on the first deploy by adopting the key in use (the env file's, else the running backend's, else a new one). Set `SECRET_KEY_BASE_ROTATION=<token>` in the `.env` file to rotate it: the old key stays valid for JWTs as `SECRET_KEY_BASE_PREVIOUS` for 60 minutes (model_driven_api >= 3.13.0). See `docs/adr/0004-secret-key-base-lives-on-the-docker-host.md`.

Optional: `ADMIN_PASSWORD`, the first admin's password. If `ADMIN_PASSWORD` is unset or empty, the seed (thecore_auth_commons >= 3.6.2) creates the first admin, `admin@BASE_DOMAIN`, with a random password written to `/root/persistence/${COMPOSE_PROJECT_NAME}/storage/admin_initial_password` on the Docker host (mode `0600`, never logged; or `docker compose exec backend cat storage/admin_initial_password`). Change it after the first login and delete the file. The admin is created only on a database without one, so setting or changing `ADMIN_PASSWORD` later has no effect. Older backends fall back to the fixed `Change#1`, so keep setting it for them.

---

## CI/CD (`.github/workflows/main.yml`)

- **Triggers**: push to `release/3`, weekly (Sunday midnight UTC), manual `workflow_dispatch`
- **Concurrency**: cancels in-progress runs for the same ref
- **Secrets required**: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`
- **Steps**:
  1. Docker Hub login
  2. Checkout with submodules
  3. Docker Buildx setup
  4. Node.js 22 + `vsce` install (for extension packaging)
  5. `./bin/build` (builds + pushes all three images)
  6. GitHub Release creation using `$DOCKERVERSION` (skips if already exists)

---

## Branch Strategy

| Branch | Purpose |
|---|---|
| `main` | Stable mainline |
| `release/N` | Active dev for major version N (current: `release/3`) |
| Feature branches | Created from the active release branch |

### Creating a New Major Version

1. Merge `release/N` into `main`
2. `git checkout -b release/N+1`
3. Update `version` file
4. Run `./bin/build`

---

## Agent Skills

Not vendored in this repo. Matt Pocock's skills come from the `mattpocock-skills` Claude Code plugin installed on the developer's **host** (`claude plugins install mattpocock-skills`), exposed in the devcontainer by the `~/.claude` bind mount; `.devcontainer/link-host-home.sh` and `.devcontainer/check-plugins.sh` run from `postCreateCommand`. `ask-matt` maps how the skills connect.

---

## Submodule

`submodules/thecore_code_extension/` — VS Code extension, tracked on branch `release/3`.

```bash
# Clone with submodules
git clone --recurse-submodules <repo-url>

# Update to latest
git submodule update --remote submodules/thecore_code_extension
```

---

## What NOT to Change

- `version` file — only change when creating a new major release branch
- `scripts/` contents — deployed globally into all Thecore environments
- `docker/docker-compose.yml` / `docker-compose.net.yml` — deployed directly to production servers
- No application code belongs here — this is infrastructure only
