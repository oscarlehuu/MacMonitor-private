---
title: "Route ccs kimi to km with bypass permissions"
description: "Adjust local zsh routing so ccs kimi uses CCS km profile with dangerous permission bypass while preserving all other ccs behavior."
status: pending
priority: P2
effort: 20m
branch: codex/performance-optimization-brainstorm
tags: [ccs, zsh, kimi, permissions]
created: 2026-03-06
---

## Goal
Make `ccs kimi` behave like `ccs km --dangerously-skip-permissions` by default, without changing behavior for any other `ccs` command or profile.

## Local Files
- `/Users/oscar/.zshrc` (primary edit target)
- `/Users/oscar/.ccs/km.settings.json` (read-only validation target)
- `/opt/homebrew/bin/ccs` (resolved binary path at runtime)

## Key Constraints
- Intercept only when first arg is exactly `kimi`.
- Preserve passthrough for all non-`kimi` invocations.
- Avoid duplicate/conflicting permission flags (`--dangerously-skip-permissions`, `--allow-dangerously-skip-permissions`, `--permission-mode`).

## Phase 1: Baseline Audit
1. Confirm current shell resolution:
   - `zsh -lc 'type ccs'`
   - `zsh -lc 'whence -p ccs'`
2. Snapshot current wrapper/config:
   - `sed -n '1,260p' ~/.zshrc`
   - `ccs --version`

## Phase 2: Wrapper Update (if needed)
1. Backup zsh config:
   - `cp ~/.zshrc ~/.zshrc.bak.$(date +%Y%m%d-%H%M%S)`
2. Ensure `ccs()` wrapper logic:
   - non-`kimi` -> exec real `ccs` binary untouched
   - `kimi` -> rewrite to `km`
   - if no explicit permission flag present -> inject `--dangerously-skip-permissions`
3. Reload shell config:
   - `source ~/.zshrc`

## Phase 3: Verification
1. Behavior preservation checks:
   - `zsh -lc 'ccs --version'`
   - `zsh -lc 'ccs api list'`
2. `kimi` routing checks:
   - `zsh -lc 'ccs kimi -p "Reply with exactly ROUTE-KIMI-OK"'`
   - Expect output shows `ccs:km` and returns `ROUTE-KIMI-OK`.
3. Explicit permission override check:
   - `zsh -lc 'ccs kimi --permission-mode bypassPermissions -p "Reply with exactly EXPLICIT-PERM-OK"'`
   - Expect success, no duplicate flag failure.

## Success Criteria
- `ccs kimi` consistently routes to `km` profile.
- Dangerous bypass is applied by default for `ccs kimi` unless explicit permission flag already exists.
- All non-`kimi` `ccs` commands keep original behavior.

## Risks
- Shell function shadowing can break if wrapper calls itself; must call binary via `whence -p ccs`.
- Mis-parsed flags can create invalid CLI args; verify with both default and explicit permission modes.

## Unresolved Questions
- None.
