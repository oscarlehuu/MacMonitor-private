# Scout 01 Report
Date: 2026-02-16
Scope: Codebase touchpoints for storage app-deletion safety + terminate-by-port feature

## Why Scout Was Required
`codebase-summary.md`, `code-standards.md`, `system-architecture.md`, and `project-overview-pdr.md` are not present in this repository snapshot. Targeted scout scan was used instead.

## Current Architecture Map
1. Storage deletion pipeline
- Selection + confirmation + async delete dispatch:
  - `/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift:56`
  - `/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift:298`
- Actual delete implementation:
  - `/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Storage/LocalStorageManager.swift:126`
- Deletion result model + summary message:
  - `/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Storage/StorageManagementModels.swift:206`

2. Process/RAM termination pipeline
- Process collection and scope switching:
  - `/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Processes/LibprocProcessListCollector.swift:16`
  - `/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift:61`
- Protection policy:
  - `/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Processes/ProcessProtectionPolicy.swift:66`
- Batch SIGTERM terminator:
  - `/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Processes/ProcessTerminating.swift:65`
- RAM UI controls and destructive confirmation:
  - `/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/RAMDetails/RAMDetailsView.swift:319`
  - `/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/RAMDetails/RAMDetailsView.swift:406`

3. Dependency injection root
- Existing construction points for storage/process services:
  - `/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/DI/AppContainer.swift:40`

## Existing Test Surface
- Storage view-model behavior tests:
  - `/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Tests/StorageManagementViewModelTests.swift:89`
- RAM details behavior tests:
  - `/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Tests/RAMDetailsViewModelTests.swift:55`
- Signal terminator mapping tests:
  - `/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Tests/SignalProcessTerminatorTests.swift:20`

## Gaps Relevant to New Scope
1. Storage flow lacks running-app preflight/quit/force-escalation state.
2. No dedicated port model, collector, or port UI mode exists.
3. No force-kill fallback workflow exists in RAM details (single-step SIGTERM only).
4. Current summaries are coarse; no explicit “still-running after graceful” bucket.

## Constraints Observed
- Repository currently has local uncommitted edits in storage files/tests; plan should avoid assuming clean baseline.
- Existing architecture favors small, testable domain services injected via `AppContainer`.

## Unresolved Questions
- Whether terminate-by-port view should live inside RAM screen (tab/segment) or separate screen entry.
