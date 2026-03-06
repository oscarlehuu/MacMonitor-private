# Context Links
- [Plan](./plan.md)
- [Phase 01](./phase-01-baseline-audit-current-tooling-and-configs.md)
- [Phase 02](./phase-02-upgrade-claudekit-and-engineerkit-safely.md)

# Overview
- Priority: P1
- Status: pending
- Brief description: migrate supported local config artifacts toward Codex, Cursor, Droid, and OpenCode, while keeping user-specific overrides deliberate and reversible.

# Key Insights
- `ck migrate` should be treated as the source of truth for generated artifacts; shell aliases are a separate layer and need manual review.
- Dry-run output is part of the deliverable because it exposes pending writes, conflicts, and remaining drift.

# Requirements
- Run a full dry-run before applying any migration.
- Apply only supported global migrations for `codex`, `cursor`, `droid`, and `opencode`.
- Update existing shell aliases/functions only when they clearly route old workflows and the replacement is deterministic.
- Avoid deleting user-specific files unless the migration tool explicitly owns them.

# Architecture
- Migration engine: `ck migrate --agent codex --agent cursor --agent droid --agent opencode --global`.
- Validation targets: generated agent/rule/hook/config files under each tool's config root.
- Manual layer: shell aliases/functions in user startup files.

# Related Code Files
- Modify: home-directory config roots and possibly shell startup files, not repo code.
- Inspect/Update: `~/.codex`, `~/.cursor`, `~/.factory`, `~/.config/opencode`, `~/.zshrc`, `~/.zprofile`.

# Implementation Steps
1. Read `ck migrate --help` and run a dry-run for all four target agents.
2. Review dry-run output for installs, updates, conflicts, and skipped items.
3. Apply the migration if the planned writes are limited to owned/generated artifacts.
4. Inspect the target config roots to confirm files were written where expected.
5. Review current shell aliases/functions and normalize only the ones that still point to legacy paths.

# Todo List
- [ ] Dry-run output captured.
- [ ] Migration applied or blocked with a reason.
- [ ] Generated files confirmed on disk.
- [ ] Alias/function cleanup completed or deliberately skipped.

# Success Criteria
- Codex, Cursor, Droid, and OpenCode each have the expected generated config artifacts.
- There is no accidental overwrite of clearly user-owned custom files.

# Risk Assessment
- Migration commands may stall on progress output even after writing files; validate on disk instead of trusting the spinner.
- Alias edits are high-risk if they silently change daily commands; keep them minimal.

# Security Considerations
- Do not expose tokens while inspecting configs.
- Leave unsupported custom overrides untouched unless the user explicitly wants them normalized.

# Next Steps
- Run smoke checks and build the before/after summary from real observed state.

