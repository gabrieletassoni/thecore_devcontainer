# CLAUDE.md — Thecore Backend DevContainer

This file provides guidance for AI assistants working in this repository.

## Mandatory Workflow for Features and Codebase Changes

**IMPORTANT**: When asked to implement a new feature or make changes to the codebase, do NOT write code directly. Instead, run the following skills in sequence:

1. `/grill-with-docs` — Gather requirements and clarify ambiguities by asking questions informed by documentation
2. `/to-spec` — Convert the gathered requirements into a Product Requirements Document
3. `/to-tickets` — Break the PRD down into discrete, actionable issues
4. `/tdd` — Implement each issue using Test-Driven Development

Only after completing this sequence should any code be written.

## Project Overview

This repository builds and publishes Docker images that provide a standardized development and deployment environment for **Thecore**-based Ruby on Rails applications. It does **not** contain a Rails application itself — it is infrastructure/tooling.

Three images are produced:
| Image | Docker Hub Tag | Purpose |
|---|---|---|
| `Dockerfile.common` | `gabrieletassoni/thecore-common` | Base image: Ruby 3.3 (patch pinned), system libraries |
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
│   │   └── package-vscode-extension.sh  # Pre-build hook: vsce package → build/thecore.vsix + build/thecore-version.txt
│   ├── version.sh          # Exports versioning variables (sourced only by build-image)
│   └── docker-push.sh      # Pushes built images to Docker Hub (sourced only by build-image)
├── docker/                 # Production runtime configs
│   ├── Dockerfile          # (unused base; actual builds use root Dockerfiles)
│   ├── docker-compose.yml  # Production services: db, cache, backend, worker
│   ├── docker-compose.net.yml  # Adds nginx-proxy + Let's Encrypt support
│   ├── docker-compose.build.yml
│   ├── installation-secrets.sh  # Keeps SECRET_KEY_BASE in the host's secrets.env (ADR 0004), run by docker-deploy.sh
│   ├── entrypoint.sh       # Rails startup: db:create, migrate, [seed]*, [assets]*, server
│   └── entrypoint-sidekiq.sh  # Sidekiq worker startup
├── scripts/                # Utility scripts copied into images at /usr/bin/
│   ├── app-compile.sh      # Builds application Docker image
│   ├── docker-build.sh     # Docker build wrapper
│   ├── docker-deploy.sh    # Deploys to remote Docker hosts via SSH (DRY_RUN=1 supported)
│   ├── gem-compile.sh      # Builds and pushes Ruby gems
│   └── thecore-motd.sh     # Warns on shell login if the project's .devcontainer predates this image's extension version; called from ~/.bashrc (Dockerfile.dev)
├── os/                     # APT/dpkg config copied into images
│   ├── 02nocache           # Disables APT caching
│   └── 01_nodoc            # Skips doc installation via dpkg
├── submodules/
│   └── thecore_code_extension/  # VS Code extension (git submodule, branch release/3)
├── .devcontainer/          # VS Code devcontainer configuration
│   ├── Dockerfile          # Docker-in-Docker setup for VS Code
│   ├── devcontainer.json
│   ├── link-host-home.sh   # postCreateCommand: /home/<host-user> -> $HOME, so the host's Claude Code plugin paths resolve
│   ├── check-plugins.sh    # postCreateCommand: warns if the mattpocock-skills plugin isn't installed on the host
│   └── library-scripts/
├── docs/adr/               # Architecture decision records (0001 nofile ulimits, 0002 customer .env, 0003 Ruby/Rails versions, 0004 SECRET_KEY_BASE on the host)
├── test/                   # Shell test suites, no docker daemon needed (see Testing)
├── .github/workflows/main.yml  # CI: push to release/3, weekly, or manual trigger
├── .github/workflows/trivy.yml # Trivy scan of the published images (see Security scanning)
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

`.github/workflows/trivy.yml` scans the published images after every successful build and nightly; see Security scanning.

## Key Conventions

### Shell Scripts

- All scripts use `#!/bin/bash -e` (exit on first error); the test suites under `test/` use `#!/bin/bash` + `set -euo pipefail` instead
- `bin/build-image` is the **only** caller of `bin/version.sh` and `bin/docker-push.sh`; individual build scripts no longer source these directly
- Shellcheck annotations (`# shellcheck source=...`) are used for static analysis
- Scripts are designed to be run from the repository root

### Testing

Each file under `test/` is a standalone bash suite; none needs a docker daemon, and CI doesn't run them, so run them by hand before pushing:

```bash
bash test/build-image.sh            # bin/build-image tagging, build-arg, push, hooks (docker mocked)
bash test/deploy-env-passthrough.sh # customer .env reaches backend/worker (needs the docker compose CLI)
bash test/installation-secrets.sh   # host secrets.env: adopt, rotate, expire (docker mocked)
bash test/version-pins.sh           # Ruby patch pinned in Dockerfile.common, Rails >= 7.2.4 in Dockerfile.dev
```

### Ruby and Rails versions

`Dockerfile.common` starts from `ruby:<full patch>-bookworm`, kept equal to the host apps' `.ruby-version`; `Dockerfile.dev` installs `rails:'~> 7.2.4'`, a minimum 7.2 patch. When an app moves its `.ruby-version`, or a new Rails 7.2 security release comes out, raise them here and push `release/3`, so CI publishes images that carry it (`docs/adr/0003-ruby-and-rails-versions-pinned.md`).

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
- Ruby and Rails never float to whatever is current at build time: `Dockerfile.common`'s `FROM` names the full Ruby patch, equal to the host apps' `.ruby-version`, and `Dockerfile.dev` installs Rails with a minimum 7.2 patch (`~> 7.2.4`: that release or a later 7.2.x). Bump both by hand together with the apps (`docs/adr/0003-ruby-and-rails-versions-pinned.md`, `test/version-pins.sh`).

### Production Services (docker-compose.yml)

Four services form the production stack:
- **db**: PostgreSQL 15, data persisted at `/root/persistence/$COMPOSE_PROJECT_NAME/db`
- **cache**: KeyDB (Redis-compatible), no persistence
- **backend**: Rails app — entrypoint runs `db:create`, `db:migrate`, `thecore:db:seed`, `assets:clobber`, `assets:precompile`, then `rails s` (all steps unconditional — convention over configuration)
- **worker**: Sidekiq, waits for backend health before starting

`backend` and `worker` both set `ulimits: nofile: {soft: 65536, hard: 1048576}` — Docker's bare default (1024 soft) is otherwise silently in effect for every container in this stack, which is easy to hit over long uptimes (see `docs/adr/0001-container-nofile-ulimits.md`). A `Dockerfile` `RUN ulimit` would **not** work here — that only affects the build-time layer, not the running container — so this must live in the compose file, which propagates to installations via the same `docker-deploy.sh` rsync-on-redeploy path as every other change here (not retroactively, to containers already running).

Key environment variables required at runtime:
- `SECRET_KEY_BASE` — Rails secret key, from the Docker host's `secrets.env`, never the `.env` file (see below)
- `APP_NAME` — Application name
- `COMPOSE_PROJECT_NAME` — Used for volume namespacing
- `BE_SUBDOMAIN`, `FE_SUBDOMAIN`, `BASE_DOMAIN` — Domain configuration
- `IMAGE_TAG_BACKEND` — Docker image to deploy

`SECRET_KEY_BASE` does not belong in the installation's `.env` file: `docker-deploy.sh` takes it from the Docker host's `/root/persistence/${COMPOSE_PROJECT_NAME}/secrets.env`, which `installation-secrets.sh` creates on the first deploy by adopting the key in use (the env file's, else the running backend's, else a new one). Set `SECRET_KEY_BASE_ROTATION=<token>` in the `.env` file to rotate it: the old key stays valid for JWTs as `SECRET_KEY_BASE_PREVIOUS` for 60 minutes (model_driven_api >= 3.13.0). See `docs/adr/0004-secret-key-base-lives-on-the-docker-host.md`.

Optional: `ADMIN_PASSWORD` — the first admin's password. If `ADMIN_PASSWORD` is unset or empty, the seed (thecore_auth_commons >= 3.6.2) creates the first admin, `admin@BASE_DOMAIN`, with a random password written to `/root/persistence/${COMPOSE_PROJECT_NAME}/storage/admin_initial_password` on the Docker host (mode `0600`, never logged; or `docker compose exec backend cat storage/admin_initial_password`). Change it after the first login and delete the file. The admin is created only on a database without one, so setting or changing `ADMIN_PASSWORD` later has no effect. Older backends fall back to the fixed `Change#1`, so keep setting it for them. `docker-compose.yml` passes it as `${ADMIN_PASSWORD:-}`, so an unset value is no compose warning.

`backend` and `worker` also load the installation's own `.env` file as `env_file: ${CUSTOMER_ENV_FILE:-/dev/null}` (`docker-deploy.sh` exports `CUSTOMER_ENV_FILE`), so an app can read a variable of its own, set per installation in `vendor/deploytargets/<provider>/<customer>.env`, without adding it to `x-vars`. `x-vars` still wins on any name both define. See `docs/adr/0002-customer-env-file-reaches-containers.md`, tested by `test/deploy-env-passthrough.sh`.

### Dev Container (vscode-devcontainers-thecore)

The dev image runs as user `vscode` with passwordless sudo and Docker group membership. The `.bashrc` configuration sets:
- `APPBIN=/workspaces/project/backend/bin`
- `COMPOSE_PROJECT_NAME=thecore_test`
- `BUNDLE_APP_CONFIG=/workspaces/project/backend/.bundle`
- Gems installed into `vendor/bundle` inside the workspace

The working directory inside the container is `/workspaces/project`.

`.bashrc` also runs `thecore-motd.sh` on every new shell. It compares `/etc/thecore/thecore-version.txt` (the Thecore extension version baked into this image at build time, written alongside `build/thecore.vsix` by `bin/hooks/package-vscode-extension.sh`) against `/workspaces/project/.devcontainer/.thecore-template-version` (stamped with the extension version by the "Thecore 3: Setup Devcontainer" command when it scaffolds `.devcontainer/`). If the scaffold predates the image, it prints a warning suggesting the user regenerate `.devcontainer/`. Silent no-op if either file is missing (legacy scaffolds, non-dev images, or projects not using this generator).

### Deployment Script (`scripts/docker-deploy.sh`)

This script handles multi-customer, multi-provider deployments:
- Reads deploy targets from `vendor/deploytargets/PROVIDER/`
- Each provider directory can have `docker_host` (production) or `docker_TARGETENV_host` (staging, etc.)
- Each `*.env` file in a provider directory represents one customer deployment
- Connects via SSH (`remote_exec`) and rsyncs (`remote_rsync`) compose files and `installation-secrets.sh`, exports the host's `secrets.env` (ADR 0004), then runs `docker compose up -d` with `CUSTOMER_ENV_FILE` set to that customer's `.env` (passed to the containers, see Production Services)
- Set `TARGETENV` environment variable to target non-production environments
- Set `DRY_RUN=1` to print all SSH and rsync commands without executing (useful for CI previews or local verification)

## Submodules

The VS Code extension lives in `submodules/thecore_code_extension/` on branch `release/3` (currently at 3.10.0). The extension's `templates/setupDevContainer/devcontainer.json` includes devcontainer features for Node.js LTS, GitHub CLI, Git LFS, Python, and Graphviz (via `apt-packages`).

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

## Security scanning

Configured in the GitHub repository settings, plus one workflow:

- **CodeQL** default setup on the Actions workflows: on every push to `release/3`, on pull requests
  and weekly. Findings: Security → Code scanning.
- **Secret scanning with push protection**: a push containing a recognised secret is rejected. It
  is the only check that blocks anything. If it fires on a real secret, remove it from the commit and
  rotate the secret; never bypass it.
- **Dependabot alerts and security updates**, but no `dependabot.yml`: a version-update config would
  open pull requests raising `Dockerfile.common`'s `FROM ruby:…`, which must stay equal to the host
  apps' `.ruby-version` (ADR 0003).
- **Trivy** (`.github/workflows/trivy.yml`) scans the three published images, tag `:3`, for fixable
  HIGH/CRITICAL vulnerabilities after every successful "Build and Push Docker Images" run and every
  night at 03:00 UTC, and uploads the results to code scanning (one category per image). After a
  build it only reports; the nightly run also fails when something is found, so the owner gets
  GitHub's "workflow failed" mail. Most findings are fixed by rebuilding (the weekly build already
  picks up patched Debian packages) or by raising the pinned Ruby patch. Its actions are pinned to
  commit SHAs, since the `aquasecurity` action tags were hijacked in March 2026: bump them by SHA.
- Findings never block a release: GitHub notifies the owner. When one needs work, open a GitHub
  issue (see Agent skills).

## Agent skills

### Issue tracker

Tasks, issues, bugs, tickets and specs for this repository live **only** in its GitHub Issues
(`gabrieletassoni/thecore_devcontainer`), handled with the `gh` CLI. See `docs/agents/issue-tracker.md`.

**Mandatory rule.** Whenever a skill or development work creates, reads, updates, comments on,
assigns, blocks or closes a task, issue, bug, ticket or spec (for example /to-tickets, /to-spec,
/triage, /wayfinder, /implement, /diagnosing-bugs, /code-review, closing a piece of work, a bug found
during a session), do it in this repository's GitHub Issues following `docs/agents/issue-tracker.md`.
Never use Odoo, `.scratch/` or local Markdown files as a tracker: Odoo is only for the repositories
on Bancolini's GitLab. `#123` means a GitHub issue number of this repository. If `gh` doesn't work,
stop and say so instead of falling back to another tracker.

### Triage labels

The five canonical triage roles map to GitHub labels with the same name (`needs-triage`,
`needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root, created lazily when the first
term or decision is resolved. See `docs/agents/domain.md`.

### Skills

Matt Pocock's skills come from the `mattpocock-skills` Claude Code plugin installed on the
developer's **host** (`claude plugins install mattpocock-skills`, official marketplace), never
vendored here: no `.agents/skills/`, `.claude/commands/` or `skills-lock.json`. Its `ask-matt` skill
maps how the skills connect.
