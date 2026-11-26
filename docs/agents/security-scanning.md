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
  HIGH/CRITICAL vulnerabilities after every successful "Build and Push Docker Images" run, and
  uploads the results to code scanning (one category per image). It has no cron of its own: the
  build runs every night at 02:00 UTC (`dist-upgrade` on a cache-less runner picks up the Debian
  security fixes published since the last build), and the scan that follows that **scheduled** build
  is the fail gate: it fails when something is found, so the owner gets GitHub's "workflow failed"
  mail. Scans after a push or a manual run only report. Before 2026-11-26 the scan ran on its own
  cron against the weekly image, so every Debian fix published mid-week left it red for days.
  Most findings are fixed by that rebuild or by raising the pinned Ruby patch. Its actions are
  pinned to commit SHAs, since the `aquasecurity` action tags were hijacked in March 2026: bump
  them by SHA.
- **Accepted findings** (`.trivyignore.yaml`): CVEs a rebuild cannot fix because upstream has not
  released the fix yet (e.g. Go modules inside Docker's `docker-buildx`/`docker-compose` plugins).
  Only the fail gate reads it; the Security tab keeps showing them. Each entry is scoped to the
  binary by `paths`, has a `statement` and an `expired_at` at most a quarter ahead
  (`test/security-scan.sh`): when it expires the gate goes red again, so rebuild, and drop the entry
  if the finding is gone or extend it with the new evidence.
- Findings never block a release: GitHub notifies the owner. When one needs work, open a GitHub
  issue (see Agent skills in `CLAUDE.md`).
