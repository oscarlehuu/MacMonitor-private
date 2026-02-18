# Release Checklist

## Automated flow (default)

Two workflows now own release automation:

1. `.github/workflows/release-please.yml` (trigger: push to `main`)
   - Scans Conventional Commit history.
   - Opens/updates a release PR (`chore: release x.y.z`).
   - On merge, creates a GitHub Release + tag (`vX.Y.Z`).
   - Docs/chore/test-only changes do not create a release.

2. `.github/workflows/release.yml` (trigger: GitHub Release `published`)
   - Builds release zip from tag version.
   - Requires Developer ID signing secrets and refuses to publish ad-hoc/unsigned app builds.
   - Sets app version at build time:
     - `MARKETING_VERSION = X.Y.Z` (from tag)
     - `CURRENT_PROJECT_VERSION = $GITHUB_RUN_NUMBER`
   - Uploads zip asset to source release.
   - Uploads same zip to `oscarlehuu/macmonitor-updates` release.
   - Regenerates and commits `appcast.xml` + per-release notes in `macmonitor-updates` (GitHub Pages feed).

## Conventional Commit mapping

Use these commit types on merge PRs to `main`:

- `feat:` -> **minor** bump (`0.2.0 -> 0.3.0`)
- `fix:` / `deps:` -> **patch** bump (`0.2.0 -> 0.2.1`)
- `feat!:` or `BREAKING CHANGE:` -> **major** bump (`0.2.0 -> 1.0.0`)
- `docs:` / `chore:` / `test:` / `refactor:` (without `fix:`/`feat:` semantics) -> no release by default

## Required repository secrets

- `RELEASE_PLEASE_TOKEN`: PAT for this source repo (`contents:write`, `pull_requests:write`, `issues:write`). Needed so release creation can trigger downstream workflows.
- `SPARKLE_PRIVATE_KEY`: export from Sparkle `generate_keys -x`.
- `UPDATES_REPO_TOKEN`: PAT with push + release access to `oscarlehuu/macmonitor-updates`.
- `APPLE_CERTIFICATE_P12_BASE64`: Developer ID Application certificate (base64-encoded `.p12`).
- `APPLE_CERTIFICATE_PASSWORD`: password for the `.p12`.
- `APPLE_SIGNING_IDENTITY`: signing identity name (for example: `Developer ID Application: Your Name (TEAMID)`).

## Manual fallback

1. Build release app archive (`MacMonitor.app` -> `.zip` or `.dmg`).
2. Sign with Developer ID Application certificate.
3. Notarize artifact and staple ticket.
4. Compute SHA-256 checksum.
5. Publish artifact + checksum in GitHub Release.
6. Install/upgrade locally using:
   - `./scripts/install-macmonitor-update.sh --source <artifact> --sha256 <hash>`
7. Verify launch and smoke-test menu bar metrics.
8. Keep previous artifact for rollback.
