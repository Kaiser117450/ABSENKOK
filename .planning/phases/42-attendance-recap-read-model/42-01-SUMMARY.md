---
phase: 42-attendance-recap-read-model
plan: 01
subsystem: database
tags: [postgresql, supabase, rpc, security-definer, attendance, portal]

requires:
  - phase: 39-employee-portal-schedule-ux
    provides: resolve_portal_employee() authenticated boundary and portal RPC ACL pattern
  - phase: 38-employee-schedule-read-model
    provides: schedule_entries/schedules composite indexes and shift slot JSON schema

provides:
  - get_portal_attendance_recap(reference_date date default null) SECURITY DEFINER RPC
  - idx_attendance_logs_employee_recap composite index (employee_id, scanned_at, type)
  - Logical-day recap row contract (20 columns) covering schedule context + attendance facts

affects:
  - 42-02 (portal recap TypeScript helper in website repo)
  - 43 (portal recap UI surface)

tech-stack:
  added: []
  patterns:
    - "FULL OUTER JOIN of schedule_entries and attendance_logs to preserve both scheduled no-scan days and unscheduled attendance-only days"
    - "Overnight orphan pulang repair: reassign pre-noon pulang to prior day only when prior day has masuk — mirrors admin Rekap Harian Dart logic in SQL"
    - "history_start = LEAST(month_start, effective_date - 13) supports both month-to-date counts and 14-day recent history from one query"

key-files:
  created:
    - sql/phase_42_portal_attendance_recap_20260323.sql

key-decisions:
  - "Break duration approximated as outer envelope (first_break → last_kembali) — matches admin Rekap Harian approximation; detailed per-break timelines deferred to a later phase"
  - "sedang_bekerja status added for the active effective_date when masuk exists but no pulang — prevents portal from showing belum_pulang false alarm during current workday"
  - "Attendance index fetches from history_start - 1 to capture orphan pulang scans that belong to the last history day via overnight repair"
  - "FULL OUTER JOIN ghost-row guard: WHERE has_schedule OR scan_count > 0 eliminates empty rows from the join"

patterns-established:
  - "Recap RPC security: REVOKE from PUBLIC and anon, GRANT only to authenticated — same ACL shape as get_portal_schedule_overview"
  - "Employee identity always resolved from resolve_portal_employee() — never accepts employee_id from caller"

requirements-completed: [ATTN-02, ATTN-03]

duration: 25min
completed: 2026-03-23
---

# Phase 42 Plan 01: Attendance Recap Read Model Summary

**Employee-scoped portal attendance recap RPC with overnight pulang repair, schedule merge, and 20-column logical-day contract covering hadir/sakit/izin/belum_pulang/tidak_hadir/libur status semantics**

## Performance

- **Duration:** 25 min
- **Started:** 2026-03-23T10:00:00Z
- **Completed:** 2026-03-23T10:25:00Z
- **Tasks:** 1 of 1
- **Files modified:** 1

## Accomplishments

- Created `sql/phase_42_portal_attendance_recap_20260323.sql` as an additive, rerunnable migration
- `get_portal_attendance_recap` RPC resolves employee identity internally from authenticated portal session — zero caller-controlled identity parameters
- Overnight repair mirrors the shipped admin Rekap Harian Dart logic: orphan next-day `pulang` before noon reassigned to prior logical day only when prior day has a `masuk` scan
- History horizon covers both month-to-date counts and 14-day recent history from one query shape

## Task Commits

1. **Task 1: Add employee-scoped portal attendance recap RPC** - `b1e6279` (feat)

## Files Created/Modified

- `sql/phase_42_portal_attendance_recap_20260323.sql` - Additive migration: recap index + `get_portal_attendance_recap` SECURITY DEFINER RPC returning 20-column logical-day recap dataset

## Decisions Made

- Break duration uses outer envelope (first_break_at → last_kembali_at) to match the existing admin Rekap Harian approximation; per-break timeline detail deferred to a later phase
- Added `sedang_bekerja` as a distinct status for the current effective_date with masuk but no pulang — prevents the portal from surfacing false `belum_pulang` alarms during an active shift
- Overnight repair fetch window extends one day before `history_start` to capture repair candidates for the earliest history day
- Ghost-row guard (`WHERE has_schedule OR scan_count > 0`) eliminates empty FULL OUTER JOIN artifacts where neither schedule nor attendance data exists

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

**External service requires manual configuration.**

Run `sql/phase_42_portal_attendance_recap_20260323.sql` in the Supabase SQL Editor before the website portal can call the recap RPC.

Steps:
1. Open Supabase Dashboard for project `tmapxdftdhxovthgbhww`
2. Navigate to SQL Editor
3. Paste and run the contents of `sql/phase_42_portal_attendance_recap_20260323.sql`
4. Verify no errors; the RPC and index are created

## Next Phase Readiness

- `get_portal_attendance_recap` RPC is ready for the website TypeScript helper (Phase 42 Plan 02)
- Row contract is stable: 20 named columns including all timestamps, status, schedule context, and break/work minutes
- Phase 43 portal recap UI can be built from the same normalized row set without a second RPC

---
*Phase: 42-attendance-recap-read-model*
*Completed: 2026-03-23*

## Self-Check: PASSED

- sql/phase_42_portal_attendance_recap_20260323.sql: FOUND
- commit b1e6279: FOUND
