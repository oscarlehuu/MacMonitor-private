# Context Links
- [Plan](./plan.md)
- [Phase 01](./phase-01-baseline-audit-current-tooling-and-configs.md)

# Overview
- Priority: P1
- Status: pending
- Brief description: identify the newest installable ClaudeKit and EngineerKit releases, then upgrade only through the supported installer path.

# Key Insights
- ClaudeKit and EngineerKit use different release channels: the CLI package version and the kit release version must both be checked.
- Safe upgrade means dry knowledge first, backup in place, then installer commands that preserve custom local files.

# Requirements
- Identify the latest ClaudeKit CLI package name and version.
- Identify the latest EngineerKit release available to `ck`.
- Upgrade only if the target version is newer and the installer path is supported.
- Re-run health checks immediately after the upgrade.

# Architecture
- Package metadata source: `npm view claudekit-cli dist-tags --json`.
- Kit metadata source: `ck versions --kit engineer --all --limit 10`.
- Upgrade path: CLI package install first, then kit refresh/install.

# Related Code Files
- Modify: none in repo expected.
- Inspect/Update: global package manager state, `~/.claude/.ck.json`, `~/.claude` managed content.

# Implementation Steps
1. Query the latest available ClaudeKit CLI release and compare with the installed version.
2. Query the latest available EngineerKit release and compare with the installed global kit.
3. Upgrade ClaudeKit CLI using the matching package manager only if the target is newer.
4. Upgrade or refresh EngineerKit using the supported `ck init` or equivalent flow with an explicit target release.
5. Re-run `ck --version` and `ck doctor` to confirm the new baseline.

# Todo List
- [ ] Latest ClaudeKit CLI release identified.
- [ ] Latest EngineerKit release identified.
- [ ] Upgrade commands chosen and executed only if needed.
- [ ] Post-upgrade health check completed.

# Success Criteria
- Installed ClaudeKit and EngineerKit match the chosen latest safe targets.
- `ck doctor` reports a healthy global install or only known non-blocking warnings.

# Risk Assessment
- Pre-release channels may be newer than stable; decide explicitly rather than drifting into them accidentally.
- Large custom `.claude` state can make kit refresh appear hung even when file writes are progressing.

# Security Considerations
- Do not accept installer prompts blindly; confirm the release target first.
- Preserve user-owned custom files during kit refresh.

# Next Steps
- Use the refreshed `ck migrate` flow against Codex, Cursor, Droid, and OpenCode.

