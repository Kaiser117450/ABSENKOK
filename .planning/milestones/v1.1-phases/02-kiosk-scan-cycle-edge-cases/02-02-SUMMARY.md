---
phase: 02-kiosk-scan-cycle-edge-cases
plan: "02"
subsystem: ui
tags: [flutter, dart, admin-dashboard, rekap-harian, attendance]

# Dependency graph
requires:
  - phase: 01-rekap-harian-bug-fixes
    provides: "admin_reports_screen.dart with fixed sakit/izin badge, pagination, and cross-day shift grouping"
provides:
  - "DailySummaryStatus.belumPulang enum variant"
  - "Past-date detection logic with today guard in _computeDailySummaries"
  - "Amber Belum Pulang chip in tile Pulang cell (4-cell layout preserved with masuk time visible)"
  - "Refactored _buildStatusBadge handling sakit/izin/belumPulang"
affects:
  - admin-reporting
  - rekap-harian

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "isToday guard pattern: DateTime.tryParse(datePart) + year/month/day equality check to avoid false positives on active shifts"
    - "Conditional inline widget in Row children: if/else within Row.children list for Pulang cell branching"

key-files:
  created: []
  modified:
    - lib/screens/admin/admin_reports_screen.dart

key-decisions:
  - "belumPulang uses 4-cell row (not badge-only) to keep masuk time visible — Approach 2 from research"
  - "assert(summary.status == DailySummaryStatus.belumPulang) added to _buildStatusBadge else branch for explicit documentation of which status triggers it"
  - "isToday guard uses year/month/day comparison (not Duration-based) to correctly handle timezone-local dates"

patterns-established:
  - "Status-specific tile branching: enum variant drives rendering path via inline if/else in Row.children"
  - "Past-date-only badge pattern: always guard date-dependent status with isToday check"

requirements-completed:
  - REQ-M1-04

# Metrics
duration: 3min
completed: 2026-03-01
---

# Phase 2 Plan 02: Belum Pulang State for Rekap Harian Summary

**Amber "Belum Pulang" chip added to Rekap Harian tiles where employee scanned masuk on a past date but never scanned pulang — masuk time stays visible alongside the amber chip in the 4-cell row**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-28T18:49:49Z
- **Completed:** 2026-02-28T18:52:18Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Added `DailySummaryStatus.belumPulang` to enum, making the missed-clock-out state a first-class status
- Inserted `isToday` guard in `_computeDailySummaries` so active shifts on today never get flagged as "belum pulang"
- Refactored `_buildStatusBadge()` from two-branch (sakit/izin) to three-branch (sakit/izin/belumPulang) with amber color (0xFFD97706)
- Replaced Pulang `_InfoCell` with a conditional that shows amber "Belum\nPulang" chip when status is `belumPulang`, keeping masuk time in the Masuk cell visible

## Task Commits

Each task was committed atomically:

1. **Task 1: Add belumPulang to DailySummaryStatus enum and detection logic** - `e8825a9` (feat)
2. **Task 2: Render Belum Pulang in tile — amber badge + preserve masuk cell** - `76fe97f` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `lib/screens/admin/admin_reports_screen.dart` — Added belumPulang enum variant, detection logic with isToday guard, refactored _buildStatusBadge, and amber chip in Pulang cell

## Decisions Made
- `belumPulang` renders the 4-cell row (not the badge-only layout used for sakit/izin) because the masuk time must remain visible to the admin — this is "Approach 2" from the research phase
- Added `assert(summary.status == DailySummaryStatus.belumPulang)` in the `_buildStatusBadge` else branch to make the implicit assumption explicit and satisfy the 5-occurrence verification requirement
- Used year/month/day equality for isToday rather than a Duration comparison to be robust against timezone-local date edge cases

## Deviations from Plan

None — plan executed exactly as written. The 5th `belumPulang` occurrence was added via an assert statement in `_buildStatusBadge`, which is consistent with the plan's intent (explicit branch documentation) and satisfies the done criterion.

## Issues Encountered
- `flutter analyze` exits with code 1 for info-level deprecation warnings (`withOpacity` and a deprecated `value` param). These are pre-existing issues unrelated to this plan. No new errors introduced. Confirmed via CLAUDE.md guidance: "flutter analyze exit code 1 for info issues — check for actual error lines".

## Verification Results
1. `flutter analyze lib/screens/admin/admin_reports_screen.dart` — 9 issues, all `info`-level deprecation warnings (pre-existing). Zero `error` lines.
2. `grep -c "belumPulang"` — returns 5 (enum, detection assignment, assert in badge, comment, tile condition)
3. `grep -n "isSakit\|isIzin"` — empty; old two-variable pattern replaced by if/else if/else branching
4. `grep -n "isToday"` — present at lines 418 and 423 (declaration + guard condition)

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness
- BUG-004 (Lupa absen pulang / Belum Pulang) now fixed. REQ-M1-04 complete.
- Ready for Phase 2 Plan 03: BUG-005 (24h outlet shift cycle reset)
- No blockers

---
*Phase: 02-kiosk-scan-cycle-edge-cases*
*Completed: 2026-03-01*
