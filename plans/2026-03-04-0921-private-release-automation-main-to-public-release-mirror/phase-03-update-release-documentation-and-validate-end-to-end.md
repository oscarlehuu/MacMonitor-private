# Context Links
- [Plan overview](./plan.md)
- `.github/workflows/release-please.yml`
- `.github/workflows/release.yml`
- `README.md`
- `scripts/release-checklist.md`

# Overview
- Priority: P2
- Status: Pending
- Description: Update operator docs and validate the full release path from `main` merge to public mirror delivery.

# Key Insights
- README/checklist already document optional public mirror; wording should be tightened to "changelog + releases only".
- Validation must cover both automated path (`push`/release events) and manual fallback (`workflow_dispatch`).

# Requirements
- Functional requirements:
  - Docs clearly define required secrets/variables and expected mirror outputs.
  - Validation checklist confirms private + public release artifacts and changelog sync.
- Non-functional requirements:
  - Keep docs concise, operator-friendly, and aligned with actual workflow behavior.

# Architecture
Validation pipeline:
1. Merge releasable PR (`fix:` or `feat:`) into `main`.
2. Confirm release PR creation/update.
3. Merge release PR and confirm GitHub release publication in private repo.
4. Confirm private release workflow completion.
5. Confirm public repo release asset exists + changelog commit present.

# Related Code Files
- Files to modify:
  - `README.md`
  - `scripts/release-checklist.md`
- Files to create:
  - None
- Files to delete:
  - None

# Implementation Steps
1. Update README release section to state open repo policy: release assets + changelog only, no source sync.
2. Update checklist with exact secret/variable names and validation commands (`gh release view`, branch checks).
3. Add one "smoke test release" runbook entry for post-change verification.
4. Ensure docs mention expected repositories explicitly:
   - private source: `oscarlehuu/macmonitor`
   - public distribution: `oscarlehuu/macmonitor-open`

# Todo List
- [ ] Rewrite mirror docs to remove ambiguity about public `gh-pages`/source sync.
- [ ] Add explicit validation commands for private/public releases and changelog diff.
- [ ] Confirm docs and workflow names match exactly.

# Success Criteria
- Maintainer can follow docs and validate full flow without tribal knowledge.
- Public repo contains only release assets + changelog updates related to releases.

# Risk Assessment
- Risk: Docs drift from workflow over time.
- Mitigation: update checklist in same PR as workflow changes.

# Security Considerations
- Reiterate no secret material or private source files are mirrored publicly.

# Next Steps
- Execute implementation PR using this plan, then run one controlled patch release validation.

# Unresolved Questions
- Should validation include automated CI assertion that only `CHANGELOG.md` is touched on public `main`?
