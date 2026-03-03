# Release Checklist

## Repository authority

- Private source-of-truth repo: `oscarlehuu/macmonitor`.
- Public distribution repo (binary + changelog only): `oscarlehuu/macmonitor-open`.
- End users download installers from GitHub Releases in `oscarlehuu/macmonitor-open` (no custom download website required).

## Automated flow (default)

Two workflows now own release automation:

1. `.github/workflows/release-please.yml` (trigger: push to `main`)
   - Scans Conventional Commit history.
   - Opens/updates a release PR (`chore: release x.y.z`).
   - On merge, creates a GitHub Release + tag (`vX.Y.Z`).
   - Docs/chore/test-only changes do not create a release.

2. `.github/workflows/release.yml` (trigger: GitHub Release `published`)
   - Builds release zip from tag version.
   - Requires Developer ID signing + Apple notarization secrets and refuses to publish ad-hoc/unsigned app builds.
   - Sets app version at build time:
     - `MARKETING_VERSION = X.Y.Z` (from tag)
     - `CURRENT_PROJECT_VERSION = $GITHUB_RUN_NUMBER`
   - Submits the release bundle to Apple notarization, waits for acceptance, and staples the ticket to `MacMonitor.app`.
   - Uploads zip asset to source release.
   - Publishes Sparkle update feed artifacts to this repo's `gh-pages` branch:
     - `appcast.xml`
     - `downloads/MacMonitor-<version>-<build>.zip`
     - `notes/MacMonitor-<version>-<build>.txt`
   - Regenerates and commits `appcast.xml` + per-release notes in that Pages branch.
   - Optional: mirrors Sparkle artifacts + `CHANGELOG.md` + release asset to a public distribution repo when `PUBLIC_DISTRIBUTION_REPO` is configured.
   - Recommended distribution pattern: set `PUBLIC_DISTRIBUTION_REPO=oscarlehuu/macmonitor-open` so public users download only from GitHub Releases.

## Conventional Commit mapping

Use these commit types on merge PRs to `main`:

- `feat:` -> **minor** bump (`0.2.0 -> 0.3.0`)
- `fix:` / `deps:` -> **patch** bump (`0.2.0 -> 0.2.1`)
- `feat!:` or `BREAKING CHANGE:` -> **major** bump (`0.2.0 -> 1.0.0`)
- `docs:` / `chore:` / `test:` / `refactor:` (without `fix:`/`feat:` semantics) -> no release by default

## Required repository secrets

- `RELEASE_PLEASE_TOKEN`: PAT for this source repo (`contents:write`, `pull_requests:write`, `issues:write`). Needed so release creation can trigger downstream workflows.
- `SPARKLE_PRIVATE_KEY`: export from Sparkle `generate_keys -x`.
- `APPLE_CERTIFICATE_P12_BASE64`: Developer ID Application certificate (base64-encoded `.p12`).
- `APPLE_CERTIFICATE_PASSWORD`: password for the `.p12`.
- `APPLE_SIGNING_IDENTITY`: signing identity name (for example: `Developer ID Application: Your Name (TEAMID)`).
- `APPLE_NOTARY_KEY_ID`: App Store Connect API key ID used by `notarytool`.
- `APPLE_NOTARY_ISSUER_ID`: App Store Connect issuer UUID paired with the API key.
- `APPLE_NOTARY_API_KEY_BASE64`: base64-encoded contents of `AuthKey_<APPLE_NOTARY_KEY_ID>.p8`.

## Optional repository secrets

- `PUBLIC_DISTRIBUTION_TOKEN`: PAT (or fine-grained token) with `contents:write` access to the public distribution repo.
- Backward-compatible fallback: if `PUBLIC_DISTRIBUTION_TOKEN` is unset, workflow uses `UPDATES_REPO_TOKEN`.

## Optional repository variables

- `UPDATES_BASE_URL`: public base URL where update feed files are hosted.
- If not set, release workflow defaults to `https://oscarlehuu.github.io/macmonitor-open`.
- Recommended: set `UPDATES_BASE_URL` explicitly so workflow output and `SPARKLE_APPCAST_URL` stay aligned.
- `PUBLIC_DISTRIBUTION_REPO`: target public repo in `owner/repo` format (example: `oscarlehuu/macmonitor-open`).

## Repository settings required once

1. Enable GitHub Pages in the private source repo.
2. Set source to branch: `gh-pages`, folder: `/ (root)`.
3. Ensure GitHub Actions can push directly to `gh-pages` (branch protection must allow it).
4. If using public distribution mirror, configure `PUBLIC_DISTRIBUTION_REPO` + `PUBLIC_DISTRIBUTION_TOKEN` in the private source repo.
5. Verify that `<UPDATES_BASE_URL>/appcast.xml` is reachable.
6. Confirm the latest release asset appears in `https://github.com/oscarlehuu/macmonitor-open/releases`.

## Manual fallback

1. Build release app archive (`MacMonitor.app` -> `.zip` or `.dmg`).
2. Sign with Developer ID Application certificate.
3. Notarize artifact and staple ticket.
4. Compute SHA-256 checksum.
5. Publish artifact + checksum in GitHub Release.
6. Install/upgrade locally using:
   - `./scripts/install-macmonitor-update.sh --source <artifact> --sha256 <hash>`
   - or `./scripts/install-latest-private-release.sh --repo <owner/repo>`
7. Verify launch and smoke-test menu bar metrics.
8. Keep previous artifact for rollback.
