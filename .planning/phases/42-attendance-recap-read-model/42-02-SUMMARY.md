---
phase: 42-attendance-recap-read-model
plan: 02
subsystem: api
tags: [astro, supabase, typescript, portal, attendance-recap]

requires:
  - phase: 42-01
    provides: "get_portal_attendance_recap RPC with logical-day normalized rows and attendance_status"
  - phase: 38-02
    provides: "getPortalReferenceDate helper and resolvePortalEmployee pattern"

provides:
  - "Typed portal helper loadPortalAttendanceRecap for Phase 43 UI wiring"
  - "PortalRecapDay interface mirroring all RPC columns including named timestamps"
  - "AttendanceSummaryCounts derived from single RPC dataset (month-to-date)"
  - "recentDays slice covering up to 14 days from same dataset"

affects: [43-portal-recap-ui]

tech-stack:
  added: []
  patterns:
    - "Portal helper pattern: resolvePortalEmployee + getPortalReferenceDate + single RPC call"
    - "Read-model normalization: raw RPC row types kept internal; exported model uses camelCase typed fields"
    - "Derived dataset pattern: all secondary views (summaryCounts, recentDays) computed from one normalized array"

key-files:
  created:
    - "C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap.ts"
  modified: []

key-decisions:
  - "summaryCounts is filtered to current calendar month (monthStart through referenceDate) — recentDays may include pre-month lookback rows from the SQL 14-day horizon"
  - "shiftIsoDate helper kept module-private (not exported) — only schedule.ts exports date utilities that portal pages need"
  - "AttendanceStatus typed as discriminated union of all status values from the SQL contract including sedang_bekerja and belum_masuk"

requirements-completed: [ATTN-02, ATTN-03]

duration: 8min
completed: 2026-03-23
---

# Phase 42 Plan 02: Attendance Recap Read Model Summary

**Typed Astro portal helper `loadPortalAttendanceRecap` that normalizes the Phase 42 RPC rows and derives month-to-date summary counts and 14-day recent history from one authenticated dataset**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-23T07:05:00Z
- **Completed:** 2026-03-23T07:13:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Created `attendance-recap.ts` with full TypeScript type coverage of the SQL contract (20 column types)
- `loadPortalAttendanceRecap` follows the existing portal helper pattern: resolves employee identity server-side via `resolvePortalEmployee`, derives reference date via `getPortalReferenceDate`, and calls `get_portal_attendance_recap` exactly once
- Month-to-date `summaryCounts` and `recentDays` both derived from the single normalized day set — no second RPC call
- All named attendance timestamps (`firstMasukAt`, `firstBreakAt`, `lastKembaliAt`, `lastPulangAt`) and `attendanceStatus` preserved for Phase 43 UI components
- TypeScript check passes (`npm run check`: ok, no errors)

## Task Commits

1. **Task 1: Create typed portal attendance recap helper** - `fff126e` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap.ts` — Typed read-model helper: interfaces, normalizer, summary derivation, `loadPortalAttendanceRecap` loader

## Decisions Made

- `summaryCounts` counts only days within the current calendar month window (`monthStart` through `referenceDate`). `recentDays` uses a 14-day window and may include pre-month lookback rows because the SQL recap horizon covers both the current month and 14 days back — these pre-month days are useful for the "recent history" panel but intentionally excluded from monthly chips.
- `AttendanceStatus` typed as a discriminated string union covering all eight status values from the SQL contract (`hadir`, `sakit`, `izin`, `belum_pulang`, `sedang_bekerja`, `tidak_hadir`, `belum_masuk`, `libur`) plus `null` for unscheduled days with no attendance.
- `shiftIsoDate` kept private to this module; `getPortalReferenceDate` from `schedule.ts` is the canonical reference date utility for portal pages.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. The RPC was deployed in Phase 42 Plan 01.

## Next Phase Readiness

- Phase 43 can import `loadPortalAttendanceRecap` and receive a fully typed `PortalAttendanceRecapModel` with employee context, summary counts, `days`, and `recentDays`
- No redesign of the underlying read model should be needed for Phase 43 UI work
- The portal attendance recap page needs to be created and wired to the helper

## Self-Check

- [x] `attendance-recap.ts` created at expected path
- [x] `fff126e` commit exists in website repo
- [x] TypeScript check passes (`npm run check`: ok no errors)

## Self-Check: PASSED

---
*Phase: 42-attendance-recap-read-model*
*Completed: 2026-03-23*
