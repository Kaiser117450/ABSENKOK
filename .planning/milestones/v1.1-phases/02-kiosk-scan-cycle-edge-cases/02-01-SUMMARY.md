---
phase: 02-kiosk-scan-cycle-edge-cases
plan: 01
subsystem: ui
tags: [flutter, supabase, attendance, kiosk, nfc, shift]

# Dependency graph
requires:
  - phase: 01-rekap-harian-bug-fixes
    provides: Fixed admin reports screen (BUG-001, BUG-002, BUG-003)
provides:
  - 24h window query for kiosk scan cycle attendance type determination
  - Overnight shift support (22:00 masuk → 06:00 pulang next day works correctly)
affects:
  - 02-02 (BUG-004: Lupa absen pulang)
  - 02-03 (any further kiosk scan cycle improvements)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "24h window query: use .gte('scanned_at', cutoff) instead of post-fetch isSameDay for shift cycle determination"

key-files:
  created: []
  modified:
    - lib/screens/kiosk/kiosk_scan_screen.dart

key-decisions:
  - "Use 24h rolling window (.gte cutoff) instead of calendar-day isSameDay — window itself is the safety net, no extra logic needed"

patterns-established:
  - "Shift cycle anchor: 24h window from now, not calendar day — avoids midnight reset for overnight shifts"

requirements-completed: [REQ-M1-05]

# Metrics
duration: 2min
completed: 2026-03-01
---

# Phase 2 Plan 01: Kiosk Scan Cycle 24h Window Summary

**Fixed overnight shift bug by replacing calendar-day isSameDay check with .gte('scanned_at', cutoff) 24-hour rolling window query in kiosk_scan_screen.dart**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-28T18:49:29Z
- **Completed:** 2026-02-28T18:51:11Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Replaced the buggy `isSameDay` post-fetch calendar-day conditional with a server-side `.gte('scanned_at', cutoff)` query filter
- Overnight shifts (e.g. masuk at 22:00 Day 1, pulang scan at 06:00 Day 2) now correctly show Istirahat/Pulang buttons instead of resetting to Masuk at midnight
- 24h window acts as natural safety net: no record in 24h means `_lastType = null` which shows Masuk (correct new-shift behavior)
- After pulang: employee's `_lastType` is set to `pulang`, causing `_buildSmartButtons()` to correctly show Masuk for new cycle

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace isSameDay check with 24h window query in _loadLastAttendance** - `83cc48d` (fix)

**Plan metadata:** _(to be committed with SUMMARY.md and state updates)_

## Files Created/Modified
- `lib/screens/kiosk/kiosk_scan_screen.dart` - `_loadLastAttendance` now uses 24h rolling window query with `.gte('scanned_at', cutoff)`, removed `isSameDay` conditional

## Decisions Made
- Used 24h rolling window via `.gte` filter on the Supabase query rather than fetching all records and filtering client-side — server-side filtering is more efficient and the window itself eliminates the need for any post-fetch date comparison

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. `flutter analyze` showed 7 pre-existing warnings/info items (unused imports, deprecated `withOpacity`) — all were pre-existing and unrelated to the change. No new errors introduced.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- 24h window fix complete, ready for 02-02 (BUG-004: Lupa absen pulang — "Belum Pulang" state)
- No blockers

---
*Phase: 02-kiosk-scan-cycle-edge-cases*
*Completed: 2026-03-01*

## Self-Check: PASSED

- FOUND: `lib/screens/kiosk/kiosk_scan_screen.dart`
- FOUND: `.planning/phases/02-kiosk-scan-cycle-edge-cases/02-01-SUMMARY.md`
- FOUND commit: `83cc48d`
- VERIFIED: `.gte('scanned_at', cutoff)` present at line 101
- VERIFIED: `isSameDay` not found in file
- VERIFIED: `cutoff` present at lines 92 (declaration) and 101 (usage)
- VERIFIED: `flutter analyze` — 0 errors (7 pre-existing warnings/info only)
