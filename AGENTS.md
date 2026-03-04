# Project Agent Notes

## Live Clarification Rule

- For this project, always install the newest local build to `/Applications/MacMonitor.app` and relaunch it when Oscar asks to clarify behavior live.
- After installing, confirm installed `CFBundleShortVersionString` and `CFBundleVersion`.

## Branch + PR + Release Rule

- Always create feature branches with `codex/` prefix (example: `codex/battery-ui-fix`).
- Use Conventional Commit prefixes for commits and PR titles:
  - `feat:` -> release-please bumps minor version.
  - `fix:` or `deps:` -> release-please bumps patch version.
  - `feat!:` or `BREAKING CHANGE:` -> release-please bumps major version.
  - `docs:`, `chore:`, `test:`, `refactor:` -> no release by default.
- Prefer squash merge with a Conventional Commit PR title so `main` gets the correct release signal.
- After merging to `main`, expect `release-please` to open/update a release PR (`chore: release x.y.z`); merge that PR to publish the GitHub release and Sparkle update assets.

## Private Distribution Rule

- Source code repo (private, source of truth): `oscarlehuu/MacMonitor-private` (this repo).
- Public distribution repo (no source code, releases/issues): `oscarlehuu/MacMonitor`.
- Never publish source snapshots or source history to `oscarlehuu/MacMonitor`.
- Sparkle update artifacts are published as binary-only feed files on this repo's `gh-pages` branch, then mirrored to the public distribution repo.
- Keep all release automation and signing/notarization secrets scoped to `oscarlehuu/MacMonitor-private` only.
