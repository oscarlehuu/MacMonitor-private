# Release Automation & External Tooling: Scope Creep in Plans Directory

**Date**: 2026-03-04 – 2026-03-06
**Severity**: Low (planning/infrastructure, no shipped impact)
**Component**: Release automation, project organization
**Status**: Pending (automation), Misplaced (external tooling)

## What Happened

Over March 4-6, I sketched out two categories of work: (1) private release automation infrastructure, and (2) external tooling plans for unrelated projects. The release automation is legitimate — a needed bridge between `main` merges and public distribution. The external tooling plans are not: they ended up in the MacMonitor `plans/` directory despite being for other projects entirely (CCS Kimi setup, ClaudeKit migration).

This is a minor incident of organizational rot. Not dangerous yet, but if it continues, plans/ becomes a dumping ground and loses utility.

## Key Items

**Release Automation (Planned, Not Implemented)**
- Goal: `main` → release-please PR → signed builds → mirror to public repo (oscarlehuu/macmonitor-open)
- Scope: Keep release-please as single source of truth; mirror only signed zip + CHANGELOG.md to public
- No source code mirroring (public repo is binary-only)
- Status: Designed but not built (blocked on: signing key setup, mirror script)

**Stray External Plans (Need Relocation)**
1. `setup-ccs-kimi-from-openclaw` (Mar 6) — CCS Kimi local environment setup
2. `ccs-kimi-route-km-bypass` (Mar 6) — CCS Kimi route mapping feature
3. `claudekit-engineerkit-environment-migration` (Mar 6) — 4-phase AI tooling stack upgrade (ClaudeKit → Codex/Cursor/Droid/OpenCode)

All three are non-MacMonitor work but were written in `/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/plans/`.

## The Brutal Truth

I used MacMonitor as a default plans dump. The project has a solid `plans/` structure, so when I had ideas for unrelated work, I just dropped them there instead of creating separate project directories or using a shared planning space.

This is lazy. It pollutes context. When I'm planning MacMonitor v0.6 in six months and grep the plans dir, I'll find CCS Kimi noise.

The automation planning also reveals procrastination: I designed a nice architecture for release automation but didn't implement it because "signing setup is annoying." So I documented it and moved on. That's not progress.

## Technical Details

**Release Automation Design**
- Workflow: `git push main` → release-please creates PR with bumped version + CHANGELOG
- On PR merge, GitHub Actions builds + signs (requires: developer certificate, private key in secrets)
- Python script mirrors to `oscarlehuu/macmonitor-open`: `git clone public-repo && cp signed-zip CHANGELOG.md && git commit && git push`
- Assumption: public repo is append-only (no deletions, keeps all releases)
- Risk: If version bump in release-please is wrong, public repo gets bad release (mitigation: manually verify before public push)

**Current State**
- Release-please is working (v0.5.3 → v0.5.13 all used it)
- Public repo exists but is manual-push only (I've been manually uploading zips)
- No CI/CD glue between them yet

**External Plans Metadata**
- CCS Kimi plans: 2 plans, ~100 lines total
- EngineerKit migration: 4 phases, ~500 lines, significant scope (environment setup, dev tool chain upgrade)
- All written in MacMonitor context but belong in their own project dirs

## What We Tried

1. **Release automation**: Started setting up GitHub Actions, realized I didn't have signing keys in secrets, stopped
2. **Shared planning space**: Considered creating `/Users/oscar/plans/` as root-level (rejected; too vague)
3. **Relocation**: Didn't actually move stray plans (that's what this entry is saying needs to happen)

## Root Cause Analysis

**Why automation is blocked:**
- Signing setup requires: (1) export developer cert from Keychain, (2) add private key to GitHub secrets, (3) update Actions workflow
- I've done this before but it's annoying and error-prone. Low motivation.
- Real blocker: fear of getting signing wrong and breaking automated releases

**Why stray plans ended up in MacMonitor:**
- MacMonitor plans dir is well-organized (clean folder structure, naming conventions)
- Other projects don't have equivalent planning setup
- I took the path of least resistance instead of creating proper structure elsewhere
- No governance rule preventing it (should have one)

## Lessons Learned

**Organization:**
- Plans directory belongs to a single project. Don't share it across projects, even if you're a solo dev.
- If you work across multiple projects, create a root `~/projects/_planning/` or equiv. Enforce it with a script that checks path on commit.
- Weak organizational habits scale badly. Fix them now even though "it doesn't matter yet."

**Release Automation:**
- Signing setup feels annoying but is worth doing once. Doing it manually for each release is worse.
- Document signing process in a separate `RELEASE_AUTOMATION.md` file (separate from regular docs) so next person (or future-you) can implement it.
- Automate after you've done it manually 3+ times and know it works.

**Procrastination Pattern:**
- "I'll design it but not implement it" is just procrastination with documentation. Don't do it.
- Either: implement it, or explicitly reject it with a reason (e.g., "not prioritized for v0.6"). Don't leave it in design limbo.

## Next Steps

1. **Immediate**: Move CCS Kimi + EngineerKit plans to their respective project directories (or delete if no longer relevant)
2. **Short term** (next 2 weeks): Implement release automation signing setup. Document it in RELEASE_AUTOMATION.md.
3. **Process**: Add pre-commit hook check: ensure no plans/ changes include external project names (catch this earlier next time)
4. **Archive**: Review all plans/ subdirectories and confirm they're MacMonitor-only. Document any cross-project patterns.
