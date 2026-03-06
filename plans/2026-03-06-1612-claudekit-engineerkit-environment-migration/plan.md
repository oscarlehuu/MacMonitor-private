---
title: "ClaudeKit EngineerKit Environment Migration"
description: "Audit the current local AI CLI setup, upgrade ClaudeKit and EngineerKit safely, migrate configs toward Codex/Cursor/Droid/OpenCode, and capture before/after behavior."
status: pending
priority: P2
effort: 3h
branch: codex/performance-optimization-brainstorm
tags: [migration, claudekit, engineerkit, codex, cursor, droid, opencode]
created: 2026-03-06
---

# Overview

Goal: update the local AI tooling stack without touching repo code, then leave a clear before/after summary of what changed in versions, generated files, and CLI behavior.

## Scope
- Inspect current installed versions, package sources, config roots, and shell routing.
- Identify the latest safe ClaudeKit CLI release and latest EngineerKit release available to the current installer flow.
- Upgrade ClaudeKit and EngineerKit with rollback coverage.
- Migrate local configs toward Codex, Cursor, Droid, and OpenCode using dry-run first, then apply if safe.
- Validate the resulting CLIs and summarize functional/behavioral deltas.

## Out Of Scope
- App code changes inside this repo, unless a tiny doc note becomes necessary.
- Unrelated global tool upgrades outside the migration path.

## Phases
1. [Phase 01](./phase-01-baseline-audit-current-tooling-and-configs.md): capture current versions, config roots, aliases, and backups.
2. [Phase 02](./phase-02-upgrade-claudekit-and-engineerkit-safely.md): identify latest versions and perform safe upgrades.
3. [Phase 03](./phase-03-migrate-local-configs-to-codex-cursor-droid-and-opencode.md): dry-run and apply tool-specific migrations plus alias cleanup where justified.
4. [Phase 04](./phase-04-validate-cli-health-and-summarize-before-after-deltas.md): smoke-test the installed CLIs and produce the before/after report.

## Dependencies
- Network access for package metadata and downloads.
- Write access to home-directory config roots such as `~/.claude`, `~/.codex`, `~/.cursor`, `~/.factory`, and `~/.config/opencode`.
- Existing package managers (`npm`, optionally `bun`/`pnpm` if current install sources require them).

## Deliverables
- Updated ClaudeKit CLI and EngineerKit, if newer safe releases exist.
- Migrated local config artifacts for Codex, Cursor, Droid, and OpenCode where the official migration flow supports them.
- A concise before/after summary covering versions, files written, remaining drift, and CLI behavior changes.

