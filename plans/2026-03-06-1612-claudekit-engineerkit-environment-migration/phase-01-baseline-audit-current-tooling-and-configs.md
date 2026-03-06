# Context Links
- [Plan](./plan.md)
- Reports: `plans/reports/`

# Overview
- Priority: P1
- Status: pending
- Brief description: capture the real local baseline before any upgrade or migration touches home-directory config.

# Key Insights
- The main risk is stale state spread across multiple config roots rather than the repo itself.
- The useful baseline is not only versions; it also includes install source, shell routing, and generated hook/rule/agent files.

# Requirements
- Record versions and binary paths for `ck`, `codex`, `cursor`, `droid`, `opencode`, `node`, `npm`, `bun`, and `pnpm` when present.
- Record current ClaudeKit and EngineerKit status using `ck --version`, `ck doctor`, and release listing commands.
- Inspect the current shell aliases/functions that influence local usage.
- Create a reversible backup before any upgrade or migration.

# Architecture
- Inputs: installed CLIs, home-directory config roots, shell startup files.
- Outputs: a before-state matrix plus compressed backups for rollback.

# Related Code Files
- Modify: none expected inside the repo.
- Inspect: `~/.claude`, `~/.codex`, `~/.cursor`, `~/.factory`, `~/.config/opencode`, `~/.zshrc`, `~/.zprofile`.

# Implementation Steps
1. Capture binary paths and versions with `which` and `--version`.
2. Capture current ClaudeKit health with `ck --version`, `ck doctor`, and any installed-kit metadata files.
3. Resolve install sources with package-manager queries such as `npm list -g --depth=0`.
4. Inspect shell startup files for aliases/functions routing old workflows.
5. Create timestamped backups of each config root before modifying anything.

# Todo List
- [ ] Version and path inventory saved in working notes.
- [ ] Current install sources identified.
- [ ] Alias/function routing reviewed.
- [ ] Backups created and verified.

# Success Criteria
- There is a trustworthy before-state for every tool in scope.
- Rollback data exists for each config root that may be changed.

# Risk Assessment
- Large config roots may make backups and later migrations slow.
- Local customizations can be mistaken for generated files unless inspected first.

# Security Considerations
- Keep backups local only.
- Do not print secrets from config files into logs or reports.

# Next Steps
- Proceed to package/release discovery and safe upgrade decisions.

