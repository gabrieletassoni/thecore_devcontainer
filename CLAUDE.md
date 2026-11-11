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

This repository builds and publishes the three Docker images (`gabrieletassoni/thecore-common`, `gabrieletassoni/vscode-devcontainers-thecore`, `gabrieletassoni/thecore`) that provide a standardized development and deployment environment for **Thecore**-based Ruby on Rails applications. It does **not** contain a Rails application itself — it is infrastructure/tooling. GitHub Actions builds and pushes all three on every push to `release/3`.

## Where things are

- `bin/` — build orchestration: `bin/build` runs all three builds; `bin/build-image IMAGE_NAME DOCKERFILE [PRE_BUILD_HOOK]` owns tagging, `DOCKERUSER` and push
- `Dockerfile.common` / `Dockerfile.dev` / `Dockerfile.deploy` — the three images (dev and deploy build on top of common)
- `docker/` — production compose files, entrypoints, `installation-secrets.sh` (copied into images at `/etc/thecore/docker/`)
- `scripts/` — utility scripts copied into images at `/usr/bin/` (`docker-deploy.sh`, `gem-compile.sh`, …)
- `.devcontainer/` — this repo's own devcontainer, incl. the canonical `heal-stale-containers.sh`
- `submodules/thecore_code_extension/` — VS Code extension (branch `release/3`)
- `test/` — standalone bash suites; `docs/adr/` — decisions; `version` — the major version

## Read before working on…

| Topic | File |
| --- | --- |
| The three images, full annotated file tree | `docs/agents/repository-structure.md` |
| Versioning, building images, new major version, CI/CD, build pipeline, Ruby/Rails pins, submodules | `docs/agents/build-and-release.md` |
| Production compose stack, runtime env vars, `SECRET_KEY_BASE`/`ADMIN_PASSWORD`, `docker-deploy.sh` | `docs/agents/production-and-deploy.md` |
| Dev image shell setup, motd, healing containers left on a deleted network | `docs/agents/devcontainer.md` |
| Running the test suites, what each covers | `docs/agents/testing.md` |
| CodeQL, secret scanning, Dependabot, Trivy | `docs/agents/security-scanning.md` |
| Tickets (GitHub Issues), triage labels, glossary/ADR layout | `docs/agents/issue-tracker.md`, `triage-labels.md`, `domain.md` |

Keep `CLAUDE.md`, or the `docs/agents/` file it points to, accurate whenever the behaviour it describes changes.

## Key Conventions

### Shell Scripts

- All scripts use `#!/bin/bash -e` (exit on first error); the test suites under `test/` use `#!/bin/bash` + `set -euo pipefail` instead, and run every command whose failure is an assertion's outcome behind `|| rc=$?`/`|| true`, so a failing case is counted and the suite goes on
- `bin/build-image` is the **only** caller of `bin/version.sh` and `bin/docker-push.sh`; individual build scripts no longer source these directly
- Shellcheck annotations (`# shellcheck source=...`) are used for static analysis
- Scripts are designed to be run from the repository root

### Testing

Each file under `test/` is a standalone bash suite; CI doesn't run them, so run them by hand before pushing (`bash test/<suite>.sh`, from the repo root). Only `heal-stale-containers.sh` needs a running docker daemon. What each suite covers: `docs/agents/testing.md`.

### Rules that always apply

- Ruby and Rails never float: `Dockerfile.common`'s `FROM` names the full Ruby patch, equal to the host apps' `.ruby-version`, and `Dockerfile.dev` installs Rails `~> 7.2.4`; bump both by hand together with the apps (ADR 0003, `test/version-pins.sh`).
- `SECRET_KEY_BASE` never goes in an installation's `.env` file: it lives in the Docker host's `secrets.env` (ADR 0004).
- `ulimits: nofile` must live in the compose file, never a `Dockerfile` `RUN ulimit` (ADR 0001).
- `.devcontainer/heal-stale-containers.sh` is the canonical copy: change it here, run `test/heal-stale-containers.sh`, then copy it everywhere (ADR 0005).
- Never use a `dependabot.yml` version-update config; pin Trivy's actions by commit SHA; never bypass secret push protection — remove and rotate the secret.
- All entrypoint steps (seed, asset clobber, asset precompile) run unconditionally on every start — seed tasks must be idempotent.

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
