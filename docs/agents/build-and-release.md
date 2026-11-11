# Build and release

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (versioning, building images, major versions, CI/CD, build pipeline, Docker images, Ruby/Rails pins, submodules). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

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

`.github/workflows/trivy.yml` scans the published images after every successful build and nightly; see `docs/agents/security-scanning.md`.

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
