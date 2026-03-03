# Context Links
- [Plan overview](./plan.md)
- `.github/workflows/release-please.yml`
- `.release-please-config.json`
- `.release-please-manifest.json`

# Overview
- Priority: P1
- Status: Pending
- Description: Ensure every merge to `main` in private repo keeps the expected `release-please` behavior: open/update release PR, then create tag/release when release PR merges.

# Key Insights
- Workflow already triggers on `push` to `main` and uses `RELEASE_PLEASE_TOKEN`.
- Release creation must use PAT (not default `GITHUB_TOKEN`) so downstream release workflows trigger reliably.
- `simple` release type + conventional commits are already configured.

# Requirements
- Functional requirements:
  - Push to `main` runs release-please.
  - Release PR (`chore: release x.y.z`) is opened/updated automatically when releasable commits exist.
  - Merged release PR creates GitHub tag/release.
- Non-functional requirements:
  - No added release complexity.
  - Keep semantics aligned with existing conventional commit mapping.

# Architecture
Event chain:
1. `push` on `main` -> `release-please.yml`.
2. `release-please-action` scans manifest/changelog state and commit history.
3. If releasable commits exist -> release PR opens/updates.
4. Merge release PR -> action creates release tag/release -> triggers publish workflow.

# Related Code Files
- Files to modify:
  - `.github/workflows/release-please.yml` (only if hardening/clarity needed)
  - `.release-please-config.json` (only if PR title/behavior tweaks needed)
- Files to create:
  - None
- Files to delete:
  - None

# Implementation Steps
1. Validate workflow permissions and PAT guard are explicit and fail-fast.
2. Keep trigger limited to `push` on `main` (+ optional manual dispatch).
3. Confirm no conflicting release automation workflow creates duplicate tags/releases.
4. Add small logging/notes if needed for faster diagnosis when no release PR is created.

# Todo List
- [ ] Validate `RELEASE_PLEASE_TOKEN` scopes in docs and workflow assumptions.
- [ ] Confirm PR title pattern and tag scheme match existing release process.
- [ ] Keep this phase minimal; avoid unnecessary release-please config expansion.

# Success Criteria
- A test `fix:` merge to `main` creates/updates release PR automatically.
- Merging that release PR creates a published GitHub release tag.

# Risk Assessment
- Risk: Token scope drift breaks release creation silently.
- Mitigation: explicit validation + documented scope requirements.

- Risk: No release PR when commit types are non-releasable.
- Mitigation: document commit-type rules clearly in README/checklist.

# Security Considerations
- Use least-privilege PAT for `RELEASE_PLEASE_TOKEN`.
- Do not expose PATs in logs.

# Next Steps
- Execute Phase 2 to tighten public mirror behavior to release assets + changelog only.

# Unresolved Questions
- Should release-please `workflow_dispatch` stay enabled in steady state?
