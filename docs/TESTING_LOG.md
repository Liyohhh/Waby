# Testing Log

## BUG-001
- Date: 2026-07-28
- Area: Multi-alert escalation / alert countdown UI
- Root cause: The old single-alert data model only tracked one global alert and one global start time, so countdown state could not remain independent per alert when multiple alerts were active.
- Fix: Refactored `AlertService` to own a list of active alerts keyed by `alertId`, moved the alert UI to a shared bottom sheet with horizontal paging, and derived countdown state per alert from `startedAt` + wall clock.

## TEST-001
- Date: 2026-07-28
- Scope: Multi-alert bottom sheet behavior
- Verified:
  - Caution sheet can be dismissed with the vertical handle gesture.
  - Warning / critical sheets do not dismiss via drag or back gesture.
  - Horizontal swipe between stacked alerts preserves each alert's independent countdown based on its own `startedAt`.
  - A new alert arriving while the sheet is already open is appended and the PageView animates to the new page.
