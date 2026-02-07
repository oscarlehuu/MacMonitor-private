# MacMonitor

Open-source macOS (Apple Silicon) menu bar monitor.

## Current scope (v1)
- Thermal state via official API (`nominal/fair/serious/critical`)
- RAM usage / total
- Storage usage / total
- Refresh every few minutes (configurable)

## Build
1. Generate project:
   - `xcodegen generate`
2. Build and test:
   - `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`

## Install new build
Use:
- `/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/scripts/install-macmonitor-update.sh`
