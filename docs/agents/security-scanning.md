# Security scanning

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (CodeQL, secret scanning, Dependabot, Trivy). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

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
  issue (see Agent skills in `CLAUDE.md`).
