---
title: "Storage & Apps UI: App Icons + Distinct Disk Buckets"
description: "Concise implementation plan to replace group placeholder icons with real app icons and make Disk Distribution colors distinct per bucket."
status: pending
priority: P2
effort: 2h
branch: fix/notarization-workflow-enforce
tags: [macos, swiftui, storage-management, ui]
created: 2026-03-03
---

# Overview
Apply two low-risk UI improvements in Storage & Apps while keeping behavior stable:
1. Use real app icons for app group rows (fallback to current placeholder icon when unavailable).
2. Use deterministic per-bucket colors for Disk Distribution chart + legend (instead of 3 category colors).

# Scope (YAGNI/KISS/DRY)
- In scope:
  - `StorageManagementView` app-group icon rendering.
  - `StorageRingChartView` color assignment logic for segments and legend bullets.
- Out of scope:
  - Storage scan/deletion/business logic.
  - Data model shape changes beyond minimal computed helpers (if needed).
  - Any new files/components.

# Phases
| # | Phase | Status | Progress | Effort | Link |
|---|---|---|---|---|---|
| 1 | Update group icons and ring bucket colors | Pending | 0% | 2h | [phase-01-update-group-icons-and-ring-bucket-colors.md](./phase-01-update-group-icons-and-ring-bucket-colors.md) |

# Expected Source Files to Change
- `MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift`
- `MacMonitor/Sources/Features/StorageManagement/StorageRingChartView.swift`

# Validation
- Build: `xcodegen generate`
- Verify: `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`
- Manual checks:
  - App group rows show each app’s actual icon (Finder/system icon).
  - If icon cannot resolve, UI still shows current placeholder glyph.
  - Chart slice and matching legend dot use the same bucket color.
  - Buckets of same category can still render different colors.

# Unresolved Questions
- None.
