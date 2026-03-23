---
phase: 45
plan: 01
subsystem: portal-attendance-recap
tags: [portal, attendance-recap, presentation, astro, typescript]
dependency_graph:
  requires: []
  provides: [row-aware-recap-presentation-helper]
  affects: [portal-attendance-history-section]
tech_stack:
  added: []
  patterns: [row-aware-presentation-helper, date-contextual-copy]
key_files:
  created: []
  modified:
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap-presentation.ts
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceHistorySection.astro
decisions:
  - "getRecapDayPresentationForDay delegates to getRecapDayPresentation for current-day rows — zero duplication of the base map"
  - "Historical sakit/izin copy changed to 'pada hari tersebut' — precise without leaking calendar dates into copy strings"
  - "Static PRESENTATION_MAP de-genericised: removed 'pada hari ini' from sakit/izin base entries since those strings now only appear via the row-aware path"
metrics:
  duration_minutes: 12
  completed_date: "2026-03-23"
  tasks_completed: 2
  files_changed: 2
---

# Phase 45 Plan 01: Attendance Recap Audit Closure Summary

**One-liner:** Row-aware recap presentation helper that generates historically accurate supporting copy for past workdays without changing the data model or recap surface layout.

## What Was Built

Added `getRecapDayPresentationForDay(day, referenceDate)` to the portal recap presentation helper. The new function resolves the v6.3 audit blocker ATTN-05: historical rows no longer receive generic "hari ini" wording that makes past unresolved gaps read as if they are happening today.

The history component `PortalAttendanceHistorySection.astro` was updated to call the row-aware helper instead of the status-only `getRecapDayPresentation`, passing both the row's `logicalDate` and the recap `referenceDate`.

## Key Changes

### attendance-recap-presentation.ts
- Removed "pada hari ini" from the static `PRESENTATION_MAP` entries for `sakit` and `izin` — these are now date-neutral in the base map
- Added `getRecapDayPresentationForDay(day, referenceDate)` which:
  - For current-day rows (`logicalDate === referenceDate`): delegates to existing `getRecapDayPresentation` unchanged
  - For historical rows: overrides `supportingCopy` on `sakit`/`izin` with "pada hari tersebut" phrasing; defensively handles `sedang_bekerja`/`belum_masuk` on past rows
- Existing `getRecapDayPresentation`, `isFollowUpStatus`, `countFollowUpDays` remain unchanged and exported

### PortalAttendanceHistorySection.astro
- Import changed from `getRecapDayPresentation` to `getRecapDayPresentationForDay`
- Call site updated to `getRecapDayPresentationForDay(day, referenceDate)` — passes row context
- All existing UI preserved: today badge, tone-driven card styling, follow-up chip, timestamp rows, notes

## Verification

Build: `npm run build` — passed clean, no type or compile errors.

Pattern check: `getRecapDayPresentationForDay`, `logicalDate`, `referenceDate` all present in the presentation helper file.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] `attendance-recap-presentation.ts` modified with new helper
- [x] `PortalAttendanceHistorySection.astro` updated to use row-aware helper
- [x] Task 1 commit: `19e7ff1`
- [x] Task 2 commit: `6982e4f`
- [x] Build passed
