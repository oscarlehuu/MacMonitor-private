---
title: "Private Release Automation with Public Mirror"
description: "Ensure merge-to-main creates release PR/release automatically and mirrors binary + changelog to oscarlehuu/macmonitor-open without source sync."
status: pending
priority: P1
effort: 3h
branch: codex/public-release-compact-settings
tags: [release-automation, github-actions, release-please, distribution]
created: 2026-03-04
---

# Overview
Adjust private repo release automation so `main` merges reliably drive release PR creation, release publication, and public distribution to `oscarlehuu/macmonitor-open` as release assets + `CHANGELOG.md` only.

# Scope (YAGNI/KISS)
- In scope:
  - Keep `release-please` as the single release PR/tag source in private repo.
  - Mirror signed zip to public repo GitHub Releases.
  - Sync only `CHANGELOG.md` to public repo `main`.
  - Remove public repo branch/file mirroring that is not required for downloads/changelog.
- Out of scope:
  - Any source-code mirroring to public repo.
  - Reworking private Sparkle publishing on source repo `gh-pages`.
  - New release tooling/platforms.

# Phases
| # | Phase | Status | Progress | Effort | Link |
|---|---|---|---|---|---|
| 1 | Harden release-please trigger and release PR behavior | Pending | 0% | 0.5h | [phase-01-verify-and-harden-release-please-auto-pr-on-main.md](./phase-01-verify-and-harden-release-please-auto-pr-on-main.md) |
| 2 | Simplify public mirror to changelog + release assets only | Pending | 0% | 1.5h | [phase-02-update-release-workflow-to-mirror-open-repo-release-assets-and-changelog-only.md](./phase-02-update-release-workflow-to-mirror-open-repo-release-assets-and-changelog-only.md) |
| 3 | Docs and end-to-end validation | Pending | 0% | 1h | [phase-03-update-release-documentation-and-validate-end-to-end.md](./phase-03-update-release-documentation-and-validate-end-to-end.md) |

# Exact Files Likely To Modify
- `.github/workflows/release-please.yml`
- `.github/workflows/release.yml`
- `README.md`
- `scripts/release-checklist.md`

# TODO Checklist
- [ ] Lock release-please path (`push -> main -> release PR`) and token assumptions.
- [ ] Keep private Sparkle publish unchanged; only simplify public mirror behavior.
- [ ] Mirror release zip to `oscarlehuu/macmonitor-open` release (create/update by tag).
- [ ] Sync only `CHANGELOG.md` to public `main`, no source files.
- [ ] Update docs/secrets/variables instructions and run manual validation path.

# Unresolved Questions
- Should `PUBLIC_DISTRIBUTION_REPO` stay configurable or be hardcoded to `oscarlehuu/macmonitor-open` in workflow?
- Should public release notes be copied exactly from private release body or reduced to changelog excerpt?
