# MacMonitor full app redesign handoff

Date: 2026-04-24
Source audit: SwiftUI code in `MacMonitor/Sources/Features`
Target: compact macOS menu bar popover, code-ready Figma source of truth

## Current app shape

- Shell: fixed-height popover, 620 pt tall, width 404-760 pt, icon-only left rail 44 pt, top thermal bar, bottom version/update footer.
- Screens in code: Memory, Storage, Trends, Settings, RAM Policy Manager, Battery. Legacy aliases: Temperature -> Memory, Storage Management -> Storage.
- Sidebar currently exposes Memory, Storage, Trends, Settings. Battery screen exists but is not in `SidebarTab.primaryItems`, so redesign must explicitly decide whether Battery is primary or nested.
- Current visual system: glassy cards, many rounded containers, multiple themes, compact SF Symbols, small type from 8-14 pt, monospaced metrics.
- Existing Storage model already sorts ring buckets by size; the UI does not make this obvious enough.

## Design principles

- Make the first screen useful at 404 pt width without resizing.
- Use dense operational layout, not marketing cards.
- Prioritize answer-first metrics: biggest offender, reclaimable amount, current risk.
- Use one visible hierarchy per screen: summary -> ranked work area -> actions.
- Keep destructive controls close to selection summary, but not above discovery.
- Avoid hidden default-expanded details for key storage information.
- Use semantic color categories consistently: Apps blue, Caches green/mint, Developer/Xcode purple, System/protected gray/orange, Delete red.

## Required Figma pages

1. `00 - Cover + Screen Index`
2. `01 - Design System`
3. `02 - App Shell`
4. `03 - Storage`
5. `04 - Memory`
6. `05 - Trends`
7. `06 - Battery`
8. `07 - Settings`
9. `08 - RAM Policy`
10. `09 - Dialogs + States`

## Core components to design

- App shell: left rail, top status strip, footer/update strip, resize affordance.
- Nav item: default, hover, selected, disabled, alert badge.
- Metric header: title, primary metric, secondary metric, status badge, inline action group.
- Dense card: default, hover, selected, warning, destructive.
- Segmented tabs/filter chips.
- Horizontal storage bar with stacked semantic segments.
- Ranked storage row with icon, name, category pill, path, size, percent, bar, checkbox, reveal action.
- Expandable group row and child row.
- Selection action bar with selected count, bytes, delete, clear, search.
- Confirmation overlay and force-quit decision dialog.
- Empty, scanning, stale, error, deleting, permission needed states.

## Storage screen target

Goal: user opens Storage and instantly sees what uses space.

Frame: 620 pt high; design at 440 pt, 560 pt, 720 pt widths.

Top zone, always visible:
- Primary line: `Storage` + `402 GB used of 994 GB` + risk badge like `41% used`.
- Top offender callout: `Largest: Xcode DerivedData - 82 GB`.
- Action group: Refresh, Add Folder.
- Stacked capacity bar: Apps / Developer / Caches / Folders / Other / Free.
- Scan source mini row: Default, Added, permission status.

Main discovery zone:
- Ranked list first, not ring first.
- Each row must show proportional bar and exact size.
- Default rows:
  - Xcode DerivedData
  - Applications
  - node_modules
  - Simulator Data
  - Browser Caches
  - App Support
  - Other Folders
- Support filters: All, Apps, Caches, Developer, Folders, Protected.
- Search stays available but secondary.

Right/detail behavior by width:
- 404-520 pt: detail expands inline below selected row.
- 560-760 pt: detail side panel can appear inside same popover width.

Deletion flow:
- Selection bar sticks below storage summary or bottom of content, never hidden under scroll.
- Confirmation overlay shows selected bytes, top 5 items, protected skipped count, running apps warning.
- Force quit dialog has three clear paths: Force Quit and Trash, Skip Running Apps, Cancel.

States to include:
- First-run permission prompt state.
- Scanning with skeleton rows.
- No targets found.
- Search no results.
- Deleting with locked rows.
- Partial delete success/failure.
- Protected item tooltip.
- Running app preflight.

## Memory screen target

- Summary top: memory pressure, used/total, swap, top process.
- Horizontal breakdown remains, but top processes list should be the main work area.
- Process/Ports segmented control, search, selected terminate bar.
- Tooltip explains Activity Monitor-aligned definitions.

States:
- Collecting memory metrics.
- Processes mode.
- Ports mode.
- Terminate confirm.
- Force kill remaining ports.
- Error/result messages.

## Trends screen target

- Window segmented control at top: 24h, 7d.
- Four stacked compact charts: Memory, Storage, CPU, Battery.
- Each chart shows current, average, peak, samples.
- Inline alert badge appears on the affected chart only.

States:
- Collecting trend points.
- Stale data.
- Low coverage.
- Alert-highlighted chart.

## Battery screen target

- Battery should be explicitly reachable in the navigation or intentionally moved into Settings; Figma must decide.
- Top: percent, charging state, power flow, health.
- Controls: start/stop, charge limit slider, automatic discharge, manual discharge, sailing, top-up, heat protection.
- Schedule and status blocks remain compact.

States:
- No battery/unavailable.
- Charging, charged, AC, battery, UPS.
- Helper unavailable/installing if exposed here.
- Sailing/heat protection advanced controls expanded.

## Settings screen target

- Settings are currently multiple cards: Menu Bar Display, Alerts, Advanced Battery, General/Diagnostics, About, Quit.
- Keep card sections but reduce vertical padding and merge small rows.
- Menu Bar composer must have a dedicated modal/sheet design.

States:
- Theme selection.
- Alert threshold rows with color swatch.
- Helper unavailable and install progress.
- Update ready/checking/failed/up to date.
- Diagnostics export success/failure.

## RAM Policy Manager target

- Dedicated screen from Settings.
- List policies with enabled toggle, app, bundle id, threshold, trigger, cooldown, edit/delete.
- Add/Edit overlay:
  - App picker
  - Bundle ID
  - Limit mode GB/Percent
  - Limit value
  - Trigger
  - Cooldown
  - Validation error

States:
- Empty policies.
- Editing existing.
- Add new.
- Running apps unavailable.
- Validation error.

## App shell decisions needed before code

- Nav should include Battery if Battery remains a real primary workflow.
- Storage should become default first-run tab if this product is storage-prioritized; otherwise Memory remains default.
- Footer can shrink to icon + version unless update action is needed.
- Theme system should keep existing palettes, but the redesign source of truth should define one default dark and one default light before theme variants.

## Current blockers

- Current Figma connector in this session is authenticated but does not expose `use_figma` or any create/edit-canvas tool.
- Available Figma tools can read existing files/nodes, create FigJam diagrams, Buzz assets, and Slides decks. They cannot create the requested complete app UI file from scratch.
