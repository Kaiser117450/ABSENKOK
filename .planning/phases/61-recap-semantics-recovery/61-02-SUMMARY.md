---
phase: 61-recap-semantics-recovery
plan: 02
subsystem: reporting
tags: [attendance, recap, admin, compatibility, flutter]
requires:
  - phase: 61-01
    provides: canonical merged admin recap dataset service and strict-vs-fallback merge contract
provides:
  - row-first admin Rekap Harian surface backed by canonical merged recap rows
  - widget regression coverage for mixed strict-plus-fallback recap behavior and pending filters
affects: [61-phase-complete, 62-schedule-gap-notices, 63-export-parity-re-lock, admin-recap]
tech-stack:
  added: []
  patterns:
    - recap UI consumes `AdminPolicyRecapDatasetService` output instead of screen-local merge logic
    - pending recap counts and filters derive from canonical recap signals
key-files:
  created: []
  modified:
    - lib/screens/admin/admin_reports_screen.dart
    - test/screens/admin/admin_reports_policy_recap_test.dart
    - test/screens/admin/rekap_harian_test.dart
key-decisions:
  - "The active Rekap Harian tab is row-first and recap-first; salary-facing PDF and spreadsheet outputs remain supporting sections instead of the only visible content."
  - "Compatibility disclosure on the recap surface uses the locked `Mode kompatibilitas aktif` copy only when fallback rows are actually injected."
patterns-established:
  - "Pending admin recap semantics are driven by `belumAbsenPulang` and `activeIncomplete` recap signals, not raw-log open-shift heuristics."
  - "Mixed strict and fallback rows stay visible in the same recap surface without fabricating lateness or absence for no-schedule compatibility rows."
requirements-completed: [RECAP-05, RECAP-06, RECAP-07]
duration: 1 min
completed: 2026-04-01
---

# Phase 61 Plan 02: Row-First Admin Recap Summary

**The active admin Rekap Harian tab now renders canonical merged day rows again, with strict and compatibility behavior visible in one recap surface and backed by real widget coverage.**

## Performance

- **Duration:** 1 min
- **Started:** 2026-04-01T12:43:44+08:00
- **Completed:** 2026-04-01T12:44:42+08:00
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Rewired `AdminReportsScreen` so the active recap tab consumes merged `AttendancePolicyRecapDay` rows from `AdminPolicyRecapDatasetService` instead of leaving the tab payroll-matrix-first.
- Restored row-level recap filtering and pending semantics using canonical recap signals, including `belumAbsenPulang` and `activeIncomplete`, while keeping strict rows and compatibility rows visible together.
- Added widget and helper regression coverage for recap filter chips, mixed strict-plus-fallback rendering, compatibility banner behavior, and honest no-schedule copy.

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewire the active Rekap Harian tab to the merged recap-row dataset** - `8d03146` (feat)
2. **Task 2: Replace the placeholder recap tests with real mixed strict-plus-fallback widget coverage** - `4c24328` (test)

## Files Created/Modified

- `lib/screens/admin/admin_reports_screen.dart` - Restored the row-first recap surface, compatibility banner, pending counts, and recap signal-based filtering.
- `test/screens/admin/admin_reports_policy_recap_test.dart` - Covers strict/fallback helper logic and row tile behavior for manager exempt, pending, and no-schedule recap rows.
- `test/screens/admin/rekap_harian_test.dart` - Covers the active recap tab end-to-end, including locked filter chips, mixed row visibility, pending filtering, and honest fallback copy.

## Decisions Made

- The admin recap surface keeps salary-facing exports accessible but subordinate to the row-level recap view, matching the phase contract that recap must be the primary operational surface again.
- Compatibility messaging is tied to actual fallback injection, so operators only see the admin recap recovery banner when no-schedule rows were synthesized.

## Deviations from Plan

- Automated verification used the Flutter tool snapshot directly via `dart flutter_tools.snapshot test ...` because the `flutter.bat` wrapper hung in this environment after repeated agent/tool contention. Test scope and results are otherwise unchanged.

## Issues Encountered

- Parallel agent execution left Flutter startup contention in the workspace, so final verification was rerun locally and serially after terminating the stuck executor process.

## User Setup Required

None.

## Next Phase Readiness

- Phase 61 now has both plan summaries and the row-first admin recap surface required to mark `RECAP-05`, `RECAP-06`, and `RECAP-07` complete.
- Phase 62 can now focus only on schedule-gap follow-up notices without reopening recap recovery semantics.

## Self-Check: PASSED

- Verified `lib/screens/admin/admin_reports_screen.dart` renders row-first recap content and the locked compatibility banner copy.
- Verified `test/screens/admin/admin_reports_policy_recap_test.dart` passes via Flutter tool snapshot.
- Verified `test/screens/admin/rekap_harian_test.dart` passes via Flutter tool snapshot.

---
*Phase: 61-recap-semantics-recovery*
*Completed: 2026-04-01*
