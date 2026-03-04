# MacMonitor

Private-source macOS (Apple Silicon) menu bar monitor.

## Current scope (v1)
- Thermal state via official API (`nominal/fair/serious/critical`)
- RAM usage / total with Activity Monitor-aligned `Memory Used`
- RAM details view (embedded in Memory tab) with Activity Monitor-aligned breakdown (`App Memory`, `Wired Memory`, `Compressed`, `Cached Files`, `Swap Used`), top processes, listening ports inspection, compact mode-aware search (processes: name/PID; ports: process/port/endpoint/PID), multi-select, and allowed-only termination
- Storage usage / total
- Refresh every few minutes (configurable)

## Build
1. Generate project:
   - `xcodegen generate`
2. Build and test:
   - `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`

## Versioning and releases
- Versioning uses SemVer (`MAJOR.MINOR.PATCH`) via `release-please`.
- Merge PRs to `main` using Conventional Commits. After each merge, `release-please` automatically opens/updates a release PR in this private repo:
  - `feat:` => minor
  - `fix:` / `deps:` => patch
  - `feat!:` or `BREAKING CHANGE:` => major
- Docs/chore/test-only merges do not create a release.
- When the release PR is merged and a tag/release is published, `Publish Release Assets` builds/signs/notarizes the app, then:
  - uploads release assets (`.zip` + `.dmg` + `.pkg`) to this private repo
  - publishes Sparkle appcast/update payload to `gh-pages` (for in-app updater; no custom website needed)
- Release workflow mirrors binary release assets + `CHANGELOG.md` to the public distribution repo (`oscarlehuu/MacMonitor` by default) for GitHub Downloads. Override target with `PUBLIC_DISTRIBUTION_REPO`; auth uses `PUBLIC_DISTRIBUTION_TOKEN` (fallback: `UPDATES_REPO_TOKEN`).
- Required CI secrets are documented in `scripts/release-checklist.md` (`RELEASE_PLEASE_TOKEN`, `SPARKLE_PRIVATE_KEY`, `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_SIGNING_IDENTITY`, `APPLE_INSTALLER_CERTIFICATE_P12_BASE64`, `APPLE_INSTALLER_CERTIFICATE_PASSWORD`, `APPLE_NOTARY_KEY_ID`, `APPLE_NOTARY_ISSUER_ID`, `APPLE_NOTARY_API_KEY_BASE64`; optional: `APPLE_INSTALLER_SIGNING_IDENTITY`).
- See `scripts/release-checklist.md` for full release flow and secrets.
- Recommended variable: `UPDATES_BASE_URL` (set explicitly to match `SPARKLE_APPCAST_URL`; current value is `https://oscarlehuu.github.io/MacMonitor`).

## Install new build
Use:
- `./scripts/install-macmonitor-update.sh`
- `./scripts/install-latest-private-release.sh --repo oscarlehuu/MacMonitor-private`

## Community
- Public issue tracker: `https://github.com/oscarlehuu/MacMonitor/issues/new/choose`
- Contributing guide: `CONTRIBUTING.md`
- Code of conduct: `CODE_OF_CONDUCT.md`
- Security policy: `SECURITY.md`
