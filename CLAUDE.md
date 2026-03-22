# CLAUDE.md — Thecore Backend DevContainer

This file provides guidance for AI assistants working in this repository.

## Project Overview

This repository builds and publishes Docker images that provide a standardized development and deployment environment for **Thecore**-based Ruby on Rails applications. It does **not** contain a Rails application itself — it is infrastructure/tooling.

Three images are produced:
| Image | Docker Hub Tag | Purpose |
|---|---|---|
| `Dockerfile.common` | `gabrieletassoni/thecore-common` | Base image: Ruby 3.3, system libraries |
| `Dockerfile.dev` | `gabrieletassoni/vscode-devcontainers-thecore` | Full dev environment with Docker, Rails tools, VS Code extension |
| `Dockerfile.deploy` | `gabrieletassoni/thecore` | Minimal production-ready image |

## Repository Structure

```
thecore_devcontainer/
├── bin/                    # Build orchestration scripts
│   ├── build               # Main entry point: runs all three builds sequentially
│   ├── build-common        # Builds thecore-common image
│   ├── build-for-dev       # Packages VS Code extension + builds dev image
│   ├── build-for-deploy    # Builds production deploy image
│   ├── version.sh          # Exports versioning variables (sourced by build scripts)
│   ├── docker-push.sh      # Pushes built images to Docker Hub (sourced after build)
│   └── increment_version.sh
├── docker/                 # Production runtime configs
│   ├── Dockerfile          # (unused base; actual builds use root Dockerfiles)
│   ├── docker-compose.yml  # Production services: db, cache, backend, worker
│   ├── docker-compose.net.yml  # Adds nginx-proxy + Let's Encrypt support
│   ├── docker-compose.build.yml
│   ├── entrypoint.sh       # Rails startup: db:create, migrate, seed, assets, server
│   └── entrypoint-sidekiq.sh  # Sidekiq worker startup
├── scripts/                # Utility scripts copied into images at /usr/bin/
│   ├── app-compile.sh      # Builds application Docker image
│   ├── docker-build.sh     # Docker build wrapper
│   ├── docker-deploy.sh    # Deploys to remote Docker hosts via SSH
│   └── gem-compile.sh      # Builds and pushes Ruby gems
├── os/                     # APT/dpkg config copied into images
│   ├── 02nocache           # Disables APT caching
│   └── 01_nodoc            # Skips doc installation via dpkg
├── submodules/
│   └── thecore_code_extension/  # VS Code extension (git submodule, branch release/3)
├── .devcontainer/          # VS Code devcontainer configuration
│   ├── Dockerfile          # Docker-in-Docker setup for VS Code
│   ├── devcontainer.json
│   └── library-scripts/
├── .github/workflows/main.yml  # CI: weekly build + manual trigger
├── Dockerfile.common       # Base image definition
├── Dockerfile.dev          # Dev image definition
├── Dockerfile.deploy       # Deploy image definition
├── .rubocop.yml            # RuboCop config (targets Ruby 2.5+)
├── version                 # Single line: current major version number (e.g. "3")
└── README.md
```

## Versioning Scheme

Version format: `MAJOR.YEAR.MONTH.DAY`

- `MAJOR` is read from the `version` file (currently `3`)
- `MINOR`, `PATCH`, `BUILD` are derived from the current date at build time
- Example: `3.2026.3.22`

This is computed in `bin/version.sh` and exported as `$DOCKERVERSION`. Each image is tagged with `:latest`, `:MAJOR`, and `:MAJOR.YEAR.MONTH.DAY`.

## Development Workflows

### Building Images Locally

```bash
# Prerequisite: docker login
docker login

# Build and push all three images
./bin/build

# Build individual images
./bin/build-common       # thecore-common
./bin/build-for-dev      # vscode-devcontainers-thecore (also packages VS Code extension)
./bin/build-for-deploy   # thecore
```

`bin/build-for-dev` automatically discovers and packages any VS Code extension found in `submodules/*/` (looks for `extension.js`) using `vsce`, outputting to `build/thecore.vsix`.

### Creating a New Major Version

1. Merge the current release branch into `main` (expect merge conflicts)
2. Create a new branch: `git checkout -b release/4`
3. Update the `version` file: change `3` to `4`
4. Make any other necessary changes for the new version
5. Run `./bin/build` to build and push

### CI/CD

GitHub Actions (`.github/workflows/main.yml`) runs:
- **Trigger**: Every Sunday at midnight UTC, or manually via `workflow_dispatch`
- **Required secrets**: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`
- **Steps**: Docker login → checkout with submodules → Node.js 20 setup → `./bin/build`

No additional configuration is needed beyond the secrets.

## Key Conventions

### Shell Scripts

- All scripts use `#!/bin/bash -e` (exit on error)
- Build scripts **source** shared helpers rather than calling them as subprocesses:
  - `source bin/version.sh` — sets `$MAJOR`, `$DOCKERVERSION`, etc.
  - `source bin/docker-push.sh` — pushes `$DOCKERTAG` with all version tags
- Shellcheck annotations (`# shellcheck source=...`) are used for static analysis
- Scripts are designed to be run from the repository root

### Docker Images

- All three images use `--build-arg THECORE_VERSION="${MAJOR}"` for version injection
- `Dockerfile.dev` builds **on top of** `thecore-common` (not from scratch)
- `Dockerfile.deploy` also builds on top of `thecore-common`
- The `scripts/` directory is copied into images at `/usr/bin/` (making scripts globally available)
- The `docker/` directory is copied into images at `/etc/thecore/docker/`

### Production Services (docker-compose.yml)

Four services form the production stack:
- **db**: PostgreSQL 15, data persisted at `/root/persistence/$COMPOSE_PROJECT_NAME/db`
- **cache**: KeyDB (Redis-compatible), no persistence
- **backend**: Rails app, entrypoint runs migrations + asset precompile + `rails s`
- **worker**: Sidekiq, waits for backend health before starting

Key environment variables required at runtime:
- `SECRET_KEY_BASE` — Rails secret key
- `ADMIN_PASSWORD` — Initial admin password
- `APP_NAME` — Application name
- `COMPOSE_PROJECT_NAME` — Used for volume namespacing
- `BE_SUBDOMAIN`, `FE_SUBDOMAIN`, `BASE_DOMAIN` — Domain configuration
- `IMAGE_TAG_BACKEND` — Docker image to deploy

### Dev Container (vscode-devcontainers-thecore)

The dev image runs as user `vscode` with passwordless sudo and Docker group membership. The `.bashrc` configuration sets:
- `APPBIN=/workspaces/project/backend/bin`
- `COMPOSE_PROJECT_NAME=thecore_test`
- `BUNDLE_APP_CONFIG=/workspaces/project/backend/.bundle`
- Gems installed into `vendor/bundle` inside the workspace

The working directory inside the container is `/workspaces/project`.

### Deployment Script (`scripts/docker-deploy.sh`)

This script handles multi-customer, multi-provider deployments:
- Reads deploy targets from `vendor/deploytargets/PROVIDER/`
- Each provider directory can have `docker_host` (production) or `docker_TARGETENV_host` (staging, etc.)
- Each `*.env` file in a provider directory represents one customer deployment
- Connects via SSH, rsyncs compose files, then runs `docker compose up -d`
- Set `TARGETENV` environment variable to target non-production environments

## Submodules

The VS Code extension lives in `submodules/thecore_code_extension/` on branch `release/3`.

When cloning this repository, use:
```bash
git clone --recurse-submodules <repo-url>
# or after cloning:
git submodule update --init --recursive
```

To update the submodule to the latest commit on its tracked branch:
```bash
git submodule update --remote submodules/thecore_code_extension
```

## What NOT to Change

- Do not modify `version` without understanding the branching model (major versions = new release branches)
- Do not add application code here — this is infrastructure only
- The `scripts/` directory contents become part of the Docker images; changes affect all Thecore apps
- `docker/docker-compose.yml` and `docker/docker-compose.net.yml` are deployed directly to production servers via `docker-deploy.sh`

## Branch Strategy

- `master` — stable mainline
- `release/N` — active development branch for major version N (current: `release/3`)
- Feature branches should be created from the active release branch

When working on this repository as an AI assistant, develop on the designated feature branch and push when complete.
