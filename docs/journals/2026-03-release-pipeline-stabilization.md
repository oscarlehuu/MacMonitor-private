# Release Pipeline Stabilization Sprint (v0.5.3–v0.5.13)

**Date**: 2026-03-01 to 2026-03-10
**Severity**: High
**Component**: CI/CD, Release Build, Signing/Notarization, Asset Distribution
**Status**: Resolved

## What Happened

Shipped 11 patch releases in 10 days (v0.5.3–v0.5.13) fixing critical blockers in release pipeline, build signing, notarization, and distribution asset generation. Each fix required shipping a new release because the previous attempt failed in GitHub Actions, local notarization, or DMG rendering. This was brutal — every release commit landed 1–2 hours after the previous one shipped.

## The Brutal Truth

This was a cascading failure cascade. Each fix exposed a new blocker downstream. The workflow was:
1. Commit a fix
2. Wait for Actions to build
3. Download DMG locally to test
4. Discover the DMG is broken or unsigned
5. Fix the script, release again

The frustrating part: these were all known issues in release tooling that we'd worked around with manual steps before, but never systematized. We burned a full day of shipping velocity on what should have been solved once.

## Technical Details

**Asset naming chaos (v0.5.3–v0.5.7)**
- DMG Applications shortcut kept breaking because we were creating a symlink with relative paths
- Commit: a6e8cc9 fixed it to use absolute path in dmg
- Then the symlink target didn't exist when Finder tried to open it
- Commit: 9113c79 ensured shortcut creation happens in the right build phase

**Notarization signing failures (v0.5.7–v0.5.8)**
- DMG built with APFS on CI, but local machines with Finder needed HFS+
- Commit: b0a6839 added HFS+ format requirement to dmg build
- Then .pkg notarization broke because we had no installer certificate selected
- Commit: 7cb8dd3 made signing identity detection automatic for .pkg
- Then spctl assessment on DMG was too strict
- Commit: 6184d1c removed brittle spctl check that wasn't portable across macOS versions

**Distributor asset validation (v0.5.8)**
- release-please was publishing both DMG and .pkg but didn't detect installer cert correctly
- Commit: a91a6a8 added signed .pkg as distribution option

## What We Tried

1. **Manual signing on CI**: Didn't work — GitHub Actions doesn't have Apple Developer certs by default. Pivoted to local-only signing assumption.
2. **Inline notarization in release-please**: Too coupled to CI workflow. Pivoted to notarization happening as part of dmg build step before Actions creates the release asset.
3. **Strict asset validation (spctl)**: Broke on different macOS versions. Dropped in favor of trusting dmg build format itself.

## Root Cause Analysis

**Systemic**: Release tooling was a junk drawer of undocumented assumptions. Each step (dmg creation → signing → notarization → asset rename → GitHub asset upload) had hardcoded paths, fragile platform detection, or missing error handling. No one person understood the whole flow end-to-end.

**Specific**:
- DMG creation wasn't idempotent — Applications shortcut would fail if it already existed
- Installer certificate selection wasn't deterministic — relied on implicit "first match"
- Asset naming relied on release-please default behavior which changed without notice
- No validation gate before uploading assets to GitHub

## Lessons Learned

1. **Release tooling must be boring**: Every line of shell script in the release pipeline should have a comment explaining why it exists and what it assumes about the OS/tools. We had zero of that.

2. **Test the full pipeline locally first**: Before merging a release fix, run the full sign → notarize → DMG → asset-verify flow end-to-end on local Mac. Don't rely on GitHub Actions to catch breakage.

3. **One commit per issue boundary**: We mixed "fix DMG symlink + fix signing identity + fix spctl check" in one PR. Split them. Each fix should be shippable and rollback-safe independently.

4. **Automate the boring part, document the rest**: The dmg creation should be so simple that an Actions runner can do it. The parts that need a developer (manual notarization verification, cert selection) should be documented with exact steps.

5. **Assets are not self-documenting**: We needed to add a checklist to the release template:
   - [ ] DMG opens in Finder
   - [ ] Applications shortcut points to /Applications
   - [ ] .pkg installs without dialogs
   - [ ] Post-install binary is signed
   - [ ] Binary passes spctl on this macOS version

## Next Steps

1. **Document the release flow**: `/docs/deployment-guide.md` needs detailed steps for dmg creation, signing, notarization, and asset verification.
2. **Add a pre-release validation script**: Before merging a release PR, run a checklist that verifies each asset.
3. **Stabilize certificate handling**: Set up a single, reproducible way to select the installer signing identity instead of implicit first-match.
4. **Lock dmg build parameters**: Document why we use HFS+, why Applications symlink is absolute, why we skip spctl. Make future maintainers understand these aren't random choices.

The pipeline is stable now, but it's fragile knowledge. Document it heavily or it will break again.
