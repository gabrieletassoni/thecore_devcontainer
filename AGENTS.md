# AGENTS.md — Thecore Backend DevContainer

This file provides guidance for AI agents working in this repository.

## Mandatory Workflow for Features and Codebase Changes

**IMPORTANT**: When asked to implement a new feature or make changes to the codebase, do NOT write code directly. Instead, run the following skills in sequence:

1. `/grill-with-docs` — Gather requirements and clarify ambiguities by asking questions informed by documentation
2. `/to-prd` — Convert the gathered requirements into a Product Requirements Document
3. `/to-issues` — Break the PRD down into discrete, actionable issues
4. `/tdd` — Implement each issue using Test-Driven Development

Only after completing this sequence should any code be written.

## General Context

See [CLAUDE.md](CLAUDE.md) for full project overview, repository structure, versioning scheme, build workflows, and conventions.

## Key Architecture Facts for Agents

These are the non-obvious structural decisions that affect how to implement features or fixes:

### Build Pipeline — Single Deep Module
`bin/build-image IMAGE_NAME DOCKERFILE [PRE_BUILD_HOOK]` is the only place that knows about tagging strategy, `DOCKERUSER`, and push mechanics. The three entry points (`build-common`, `build-for-dev`, `build-for-deploy`) are one-liners that call it. When adding a new image or changing build behavior, change `bin/build-image` — not the entry points.

Pre-build hooks (optional third arg) live in `bin/hooks/` and run as isolated subprocesses, not sourced.

### Docker Entrypoint — Conditional Steps
`docker/entrypoint.sh` guards two expensive steps:
- **Seed**: only runs if `SEED_ON_START=true` (idempotent but can be slow — opt-in per container)
- **Asset precompile**: skipped if `public/assets/` already exists; force with `RECOMPILE_ASSETS=true`

`db:create` and `db:migrate` remain unconditional (idempotent, fast).

### Deploy Script — DRY_RUN Seam
`scripts/docker-deploy.sh` exposes a `DRY_RUN=1` environment variable. When set, `remote_exec` and `remote_rsync` log their commands instead of running SSH/rsync. Use this to verify deploy logic in CI previews or local runs without needing SSH access.

### Test Harness
`test/build-image.sh` tests `bin/build-image`. It mocks `docker` and `bin/docker-push.sh` using a temp `$PATH` override. Run with `bash test/build-image.sh` from the repo root.
