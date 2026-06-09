# CLAUDE.md — Thecore Backend DevContainer

This file provides guidance for AI assistants working in this repository.

## Mandatory Workflow for Features and Codebase Changes

**IMPORTANT**: When asked to implement a new feature or make changes to the codebase, do NOT write code directly. Instead, run the following skills in sequence:

1. `/grill-with-docs` — Gather requirements and clarify ambiguities by asking questions informed by documentation
2. `/to-prd` — Convert the gathered requirements into a Product Requirements Document
3. `/to-issues` — Break the PRD down into discrete, actionable issues
4. `/tdd` — Implement each issue using Test-Driven Development

Only after completing this sequence should any code be written.

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
│   ├── build-image         # Deep module: owns tagging, DOCKERUSER, build-arg, push
│   ├── build-common        # Delegates to build-image (thecore-common)
│   ├── build-for-dev       # Delegates to build-image (dev image + VS Code extension hook)
│   ├── build-for-deploy    # Delegates to build-image (thecore deploy image)
│   ├── hooks/
│   │   └── package-vscode-extension.sh  # Pre-build hook: vsce package → build/thecore.vsix
│   ├── version.sh          # Exports versioning variables (sourced only by build-image)
│   └── docker-push.sh      # Pushes built images to Docker Hub (sourced only by build-image)
├── docker/                 # Production runtime configs
│   ├── Dockerfile          # (unused base; actual builds use root Dockerfiles)
│   ├── docker-compose.yml  # Production services: db, cache, backend, worker
│   ├── docker-compose.net.yml  # Adds nginx-proxy + Let's Encrypt support
│   ├── docker-compose.build.yml
│   ├── entrypoint.sh       # Rails startup: db:create, migrate, [seed]*, [assets]*, server
│   └── entrypoint-sidekiq.sh  # Sidekiq worker startup
├── scripts/                # Utility scripts copied into images at /usr/bin/
│   ├── app-compile.sh      # Builds application Docker image
│   ├── docker-build.sh     # Docker build wrapper
│   ├── docker-deploy.sh    # Deploys to remote Docker hosts via SSH (DRY_RUN=1 supported)
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
├── .github/workflows/main.yml  # CI: push to release/3, weekly, or manual trigger
├── Dockerfile.common       # Base image definition
├── Dockerfile.dev          # Dev image definition
├── Dockerfile.deploy       # Deploy image definition
├── .rubocop.yml            # RuboCop config (targets Ruby 2.5+)
├── version                 # Single line: current major version number (e.g. "3")
└── README.md
```

_All entrypoint steps (seed, asset clobber, asset precompile) run unconditionally on every start — convention over configuration._

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

# Override Docker Hub username (default: gabrieletassoni)
DOCKERUSER=myorg ./bin/build
```

All three entry points delegate to `bin/build-image IMAGE_NAME DOCKERFILE [PRE_BUILD_HOOK]`, which owns tagging (`:latest`, `:MAJOR`, `:DOCKERVERSION`), `DOCKERUSER`, and push mechanics. The VS Code extension is packaged via `bin/hooks/package-vscode-extension.sh`, which discovers any extension in `submodules/*/` (looks for `extension.js`) using `vsce`, outputting to `build/thecore.vsix`.

### Creating a New Major Version

1. Merge the current release branch into `main` (expect merge conflicts)
2. Create a new branch: `git checkout -b release/4`
3. Update the `version` file: change `3` to `4`
4. Make any other necessary changes for the new version
5. Run `./bin/build` to build and push

### CI/CD

GitHub Actions (`.github/workflows/main.yml`) runs:
- **Trigger**: Push to `release/3`, every Sunday at midnight UTC, or manually via `workflow_dispatch`
- **Required secrets**: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`
- **Steps**: Docker login → checkout with submodules → Node.js 22 + `vsce` setup → `./bin/build` → GitHub Release creation

No additional configuration is needed beyond the secrets.

## Key Conventions

### Shell Scripts

- All scripts use `#!/bin/bash -e` (exit on first error)
- `bin/build-image` is the **only** caller of `bin/version.sh` and `bin/docker-push.sh`; individual build scripts no longer source these directly
- Shellcheck annotations (`# shellcheck source=...`) are used for static analysis
- Scripts are designed to be run from the repository root

### Build Pipeline

The three entry points (`build-common`, `build-for-dev`, `build-for-deploy`) are thin callers — one line each:

```bash
bin/build-image IMAGE_NAME DOCKERFILE [PRE_BUILD_HOOK]
```

`bin/build-image` owns:
- `DOCKERUSER` (default: `gabrieletassoni`, override via env)
- Three-tag strategy: `:latest`, `:MAJOR`, `:DOCKERVERSION`
- `--build-arg THECORE_VERSION="${MAJOR}"` injection
- Sourcing `bin/version.sh` and `bin/docker-push.sh`
- Pre-build hook invocation (optional third argument, run as a subprocess)

Pre-build hooks live in `bin/hooks/`. Currently: `bin/hooks/package-vscode-extension.sh`.

### Docker Images

- `Dockerfile.dev` builds **on top of** `thecore-common` (not from scratch)
- `Dockerfile.deploy` also builds on top of `thecore-common`
- The `scripts/` directory is copied into images at `/usr/bin/` (making scripts globally available)
- The `docker/` directory is copied into images at `/etc/thecore/docker/`

### Production Services (docker-compose.yml)

Four services form the production stack:
- **db**: PostgreSQL 15, data persisted at `/root/persistence/$COMPOSE_PROJECT_NAME/db`
- **cache**: KeyDB (Redis-compatible), no persistence
- **backend**: Rails app — entrypoint runs `db:create`, `db:migrate`, `thecore:db:seed`, `assets:clobber`, `assets:precompile`, then `rails s` (all steps unconditional — convention over configuration)
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
- Connects via SSH (`remote_exec`) and rsyncs (`remote_rsync`) compose files, then runs `docker compose up -d`
- Set `TARGETENV` environment variable to target non-production environments
- Set `DRY_RUN=1` to print all SSH and rsync commands without executing (useful for CI previews or local verification)

## Submodules

The VS Code extension lives in `submodules/thecore_code_extension/` on branch `release/3` (currently at 3.1.8). The extension's `templates/setupDevContainer/devcontainer.json` includes devcontainer features for Node.js LTS, GitHub CLI, Git LFS, Python, and Graphviz (via `apt-packages`).

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
