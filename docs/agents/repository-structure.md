# Repository structure

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (the three images, annotated file tree, entrypoint note). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

## Images

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
│   ├── thecore-app-dir.sh  # Prints the mounted app's folder (/workspaces/app or /workspaces/project/backend); used by ~/.bashrc (Dockerfile.dev)
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
│   ├── heal-stale-containers.sh  # initializeCommand, on the host: removes the project's containers left on a deleted network (ADR 0005); canonical copy of the one every Thecore app carries
│   └── library-scripts/
├── docs/adr/               # Architecture decision records (0001 nofile ulimits, 0002 customer .env, 0003 Ruby/Rails versions, 0004 SECRET_KEY_BASE on the host, 0005 heal containers left on a deleted network)
├── test/                   # Shell test suites (see `docs/agents/testing.md`)
├── .github/workflows/main.yml  # CI: push to release/3, weekly, or manual trigger
├── .github/workflows/trivy.yml # Trivy scan of the published images (see `docs/agents/security-scanning.md`)
├── Dockerfile.common       # Base image definition
├── Dockerfile.dev          # Dev image definition
├── Dockerfile.deploy       # Deploy image definition
├── .rubocop.yml            # RuboCop config (targets Ruby 2.5+)
├── version                 # Single line: current major version number (e.g. "3")
└── README.md
```

_All entrypoint steps (seed, asset clobber, asset precompile) run unconditionally on every start — convention over configuration._
