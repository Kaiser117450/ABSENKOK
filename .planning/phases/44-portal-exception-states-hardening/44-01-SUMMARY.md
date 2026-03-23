---
phase: 44-portal-exception-states-hardening
plan: 01
subsystem: portal-presentation
tags: [recap, exception-states, presentation-helper, typescript, sql-docs]
dependency_graph:
  requires: [42-01, 43-03]
  provides: [attendance-recap-presentation.ts, sql-exception-taxonomy]
  affects: [portal-attendance-history, portal-attendance-summary]
tech_stack:
  added: []
  patterns: [typed-presentation-helper, follow-up-taxonomy]
key_files:
  created:
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap-presentation.ts
  modified:
    - C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/sql/phase_42_portal_attendance_recap_20260323.sql
decisions:
  - "belum_pulang and tidak_hadir are the only follow-up gap statuses; sedang_bekerja and belum_masuk stay informational"
  - "Presentation helper imports AttendanceStatus and PortalRecapDay from attendance-recap.ts — no second contract"
  - "countFollowUpDays() operates on the existing PortalRecapDay[] dataset — no second query"
metrics:
  duration_minutes: 15
  completed_date: "2026-03-23"
  tasks_completed: 2
  files_changed: 2
---

# Phase 44 Plan 01: Exception State Contract Summary

One-liner: Typed recap exception taxonomy with SQL source comments and a portal presentation helper that maps follow-up gaps from informational current-day states.

## What Was Done

Two changes that together form one shared exception contract for the portal recap surface:

1. **SQL source commentary** — The `with_status` derivation block in `phase_42_portal_attendance_recap_20260323.sql` now explicitly documents which statuses are prior-day follow-up gaps (`belum_pulang`, `tidak_hadir`) and which are current-day informational states (`sedang_bekerja`, `belum_masuk`). A summary taxonomy block was added at the end for future reference. The deployed RPC shape was not changed.

2. **Portal presentation helper** — `attendance-recap-presentation.ts` is a new TypeScript module in the website repo that imports `AttendanceStatus` and `PortalRecapDay` from the existing `attendance-recap.ts` and exports:
   - `RecapDayPresentation` type (label, tone, needsFollowUp, followUpLabel, supportingCopy)
   - `RecapDayTone` union
   - `getRecapDayPresentation(status)` — maps any `AttendanceStatus` to presentation data
   - `isFollowUpStatus(status)` — returns true only for `belum_pulang` and `tidak_hadir`
   - `countFollowUpDays(days)` — aggregate helper for page-level framing

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Only `belum_pulang` and `tidak_hadir` are follow-up gaps | These are prior-day unresolved states; `sedang_bekerja` and `belum_masuk` are current-day in-progress states that should not show as warnings |
| Import from `attendance-recap.ts` instead of duplicating | Prevents a second status contract from drifting away from the RPC row type |
| `countFollowUpDays()` operates on existing `PortalRecapDay[]` | No additional query needed; Phase 44 UI components receive the full `days` array from `loadPortalAttendanceRecap` already |
| Tone `accent` for current-day informational states | Visually distinct from `warning` (follow-up) but still distinguishable from resolved `neutral`/`success` outcomes |

## Deviations from Plan

None — plan executed exactly as written.

## Task Summary

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Clarify exception-state semantics in recap SQL | 24f97c4 | sql/phase_42_portal_attendance_recap_20260323.sql |
| 2 | Create typed recap presentation helper | 5ee50a6 | src/lib/portal/attendance-recap-presentation.ts |

## Verification

- SQL source and portal helper describe the same exception taxonomy: belum_pulang + tidak_hadir as follow-up, sedang_bekerja + belum_masuk as informational
- Portal helper imports `AttendanceStatus` and `PortalRecapDay` from `attendance-recap.ts` — no second contract
- `npm run check` passes for all Astro/portal source files; pre-existing Deno edge-function type errors in `supabase/functions/` are unrelated and were present before this plan

## Self-Check: PASSED

- FOUND: `C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap-presentation.ts`
- FOUND: commit 24f97c4 (SQL docs) in flutter repo
- FOUND: commit 5ee50a6 (presentation helper) in website repo
