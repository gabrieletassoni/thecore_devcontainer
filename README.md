# Thecore Backend DevContainer

Builds and publishes Docker images that provide a standardized development and deployment environment for **Thecore**-based Ruby on Rails applications.

## Images

| Image | Docker Hub Tag | Purpose |
|---|---|---|
| `Dockerfile.common` | [`gabrieletassoni/thecore-common`](https://hub.docker.com/repository/docker/gabrieletassoni/thecore-common) | Base: Ruby 3.3, system libraries, shared scripts |
| `Dockerfile.dev` | [`gabrieletassoni/vscode-devcontainers-thecore`](https://hub.docker.com/repository/docker/gabrieletassoni/vscode-devcontainers-thecore) | Full dev environment: Docker-in-Docker, Rails tools, VS Code extension |
| `Dockerfile.deploy` | [`gabrieletassoni/thecore`](https://hub.docker.com/repository/docker/gabrieletassoni/thecore) | Minimal production image: Rails server + Sidekiq |

Build order is always: **common → dev → deploy**.

## Building

```bash
# Prerequisite
docker login

# Build and push all three images
./bin/build

# Build individual images
./bin/build-common       # thecore-common
./bin/build-for-dev      # dev image (also packages the VS Code extension)
./bin/build-for-deploy   # deploy image

# Override Docker Hub username (default: gabrieletassoni)
DOCKERUSER=myorg ./bin/build
```

All three entry points delegate to `bin/build-image`, which owns tagging, versioning, and push mechanics.

## Versioning

Format: `MAJOR.YEAR.MONTH.DAY` (e.g. `3.2026.6.9`). The `MAJOR` component is read from the `version` file. Each image is tagged `:latest`, `:MAJOR`, and `:MAJOR.YEAR.MONTH.DAY`.

## Production Environment Variables

Two entrypoint behaviors are opt-in to keep restarts fast:

| Variable | Default | Effect |
|---|---|---|
| `SEED_ON_START` | `false` | Set to `true` to run `thecore:db:seed` on start |
| `RECOMPILE_ASSETS` | `false` | Set to `true` to force asset recompile even if `public/assets` exists |

Required variables: `SECRET_KEY_BASE`, `ADMIN_PASSWORD`, `APP_NAME`, `COMPOSE_PROJECT_NAME`, `IMAGE_TAG_BACKEND`, `BE_SUBDOMAIN`, `FE_SUBDOMAIN`, `BASE_DOMAIN`.

## Creating a New Major Version

1. Merge the current release branch into `main` (expect merge conflicts)
2. `git checkout -b release/4`
3. Update the `version` file: change `3` to `4`
4. Run `./bin/build`

## CI/CD

GitHub Actions (`.github/workflows/main.yml`) triggers on push to `release/3`, weekly (Sunday midnight UTC), or manually. Requires `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets.
