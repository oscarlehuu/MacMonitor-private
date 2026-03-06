---
title: "Setup CCS With Kimi From OpenClaw Config"
description: "Install CCS, create/update a Kimi API profile, and validate it using existing OpenClaw Kimi credentials."
status: completed
priority: P2
effort: 45m
branch: codex/performance-optimization-brainstorm
tags: [ccs, kimi, openclaw, cli, config]
created: 2026-03-06
---

## Objective
Set up `ccs` on this machine and configure a working Kimi profile by reusing existing Kimi-related config from OpenClaw without exposing secrets.

## Scope
- In scope: local install/config for `ccs` and Kimi profile validation.
- Out of scope: app source code changes, CI/CD, commits.

## Source Of Truth (Existing Local Config)
- `/Users/oscar/.openclaw/openclaw.json`
- `/Users/oscar/.openclaw/agents/main/agent/auth-profiles.json` (`profiles["kimi-coding:default"].key`)
- Expected Kimi-compatible endpoint in existing config: `https://api.kimi.com/coding/`

## Target CCS Files
- `~/.ccs/config.yaml`
- `~/.ccs/km.settings.json` (or profile-specific `~/.ccs/<name>.settings.json`)

## Implementation TODOs
1. Preflight and backup
- `node -v && npm -v`
- `command -v ccs || true`
- `[ -f ~/.ccs/config.yaml ] && cp ~/.ccs/config.yaml ~/.ccs/config.yaml.bak.$(date +%Y%m%d-%H%M%S)`
- `[ -f ~/.ccs/km.settings.json ] && cp ~/.ccs/km.settings.json ~/.ccs/km.settings.json.bak.$(date +%Y%m%d-%H%M%S)`

2. Install or upgrade CCS
- `npm install -g @kaitranntt/ccs`
- `ccs --version`

3. Create/update Kimi API profile using existing key
- `export KIMI_API_KEY=\"$(jq -r '.profiles["kimi-coding:default"].key' /Users/oscar/.openclaw/agents/main/agent/auth-profiles.json)\"`
- `ccs api create km --preset km --api-key \"$KIMI_API_KEY\" --model kimi-k2.5 --force --yes`
- `unset KIMI_API_KEY`

4. Verify resulting CCS profile config
- `ccs api list`
- `jq '.env | {ANTHROPIC_BASE_URL, ANTHROPIC_MODEL}' ~/.ccs/km.settings.json`
- Confirm:
- `ANTHROPIC_BASE_URL == "https://api.kimi.com/coding/"`
- `ANTHROPIC_MODEL == "kimi-k2.5"` (or chosen model)

5. Runtime validation
- `ccs km -p "Reply exactly: KM_OK"`
- `ccs config` (optional UI verification at `http://localhost:3000`)

## Risks + Mitigation
- Risk: wrong endpoint/model pair breaks requests.
- Mitigation: enforce `--preset km`, then verify `~/.ccs/km.settings.json` values before first real use.

- Risk: API key exposure in shell history/logs.
- Mitigation: load key from file into env var, avoid inline literals, `unset` immediately after profile creation.

## Success Criteria
- `ccs --version` runs.
- `ccs api list` shows `km`.
- `~/.ccs/km.settings.json` contains Kimi base URL + model.
- `ccs km -p "Reply exactly: KM_OK"` returns successful response.

## Verified Outcome
- Completed: `ccs` installed, `km` profile active in `~/.ccs`, and runtime validation passed (`ccs km -p "Reply with exactly CCS-KIMI-OK"` returned `CCS-KIMI-OK`).

## Unresolved Questions
- None.
