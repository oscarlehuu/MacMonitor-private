# Context Links
- [Plan overview](./plan.md)
- `.github/workflows/release.yml`
- `README.md`
- `scripts/release-checklist.md`

# Overview
- Priority: P1
- Status: Pending
- Description: Update public mirror behavior so `oscarlehuu/macmonitor-open` contains only release assets (GitHub Releases) and `CHANGELOG.md`, with zero source sync.

# Key Insights
- Current mirror step already uploads release zip to public releases and syncs `CHANGELOG.md`.
- Current mirror step also mirrors private `gh-pages` files (`appcast.xml`, `downloads/*`, `notes/*`) to public `gh-pages`.
- Requirement only needs public repo as changelog + releases download surface.

# Requirements
- Functional requirements:
  - On private release publish, upload same zip asset to `oscarlehuu/macmonitor-open` release by tag.
  - Keep/create matching tag release in public repo.
  - Sync only `CHANGELOG.md` to public `main`.
  - Do not copy source files to public repo.
- Non-functional requirements:
  - Idempotent reruns (`gh release upload --clobber`, safe commits).
  - Keep private Sparkle publishing unchanged.

# Architecture
Flow:
1. Private release workflow builds/signs/notarizes artifact.
2. Private repo release gets asset upload.
3. Mirror step authenticates to public repo via `PUBLIC_DISTRIBUTION_TOKEN`.
4. Mirror step performs only:
   - public release create/update + asset upload
   - public `main` `CHANGELOG.md` sync commit (if changed)
5. Skip any public `gh-pages` copy path.

# Related Code Files
- Files to modify:
  - `.github/workflows/release.yml`
- Files to create:
  - None
- Files to delete:
  - None (remove logic blocks in-place)

# Implementation Steps
1. In mirror step, keep strict repo/token validation and `owner/repo` format check.
2. Remove public `gh-pages` clone/copy/commit/push block.
3. Keep public `main` clone + `CHANGELOG.md` copy + conditional commit.
4. Keep public release create/update logic and ensure notes fallback is stable.
5. Optionally pin `PUBLIC_DISTRIBUTION_REPO` default to `oscarlehuu/macmonitor-open` if this repo is fixed.

# Todo List
- [ ] Delete public `gh-pages` mirroring commands from mirror step.
- [ ] Retain only `CHANGELOG.md` sync to public `main`.
- [ ] Retain/create `gh release` mirroring by tag with upload `--clobber`.
- [ ] Verify no workflow path writes any private source tree to public repo.

# Success Criteria
- New private release appears in `oscarlehuu/macmonitor-open` releases with zipped asset.
- `oscarlehuu/macmonitor-open` `main` has updated `CHANGELOG.md`.
- No non-changelog files are pushed to public `main`.
- No Sparkle/private-pages regression in source repo.

# Risk Assessment
- Risk: Public token missing/invalid blocks mirror.
- Mitigation: explicit required-secret check with clear fail reason.

- Risk: Manual reruns create duplicate releases/assets.
- Mitigation: keep `gh release view` + create/update + `--clobber` pattern.

# Security Considerations
- Public token should be scoped to target public repo only.
- Do not mirror private metadata beyond release notes/changelog.

# Next Steps
- Execute Phase 3 documentation updates + end-to-end rehearsal.

# Unresolved Questions
- Should public repo release body mirror full private release notes or only changelog deltas?
