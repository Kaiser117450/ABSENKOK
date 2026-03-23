---
phase: 43-portal-attendance-recap-surface
plan: "01"
subsystem: portal-ui
tags: [astro, attendance-recap, mobile-first, portal-components]
dependency_graph:
  requires:
    - 42-attendance-recap-read-model (PortalAttendanceRecapModel, AttendanceSummaryCounts, PortalRecapDay)
  provides:
    - PortalAttendanceSummary.astro (shared month-summary card component)
    - PortalAttendanceHistorySection.astro (shared recent-history card list)
  affects:
    - Phase 43 route wiring (43-02 can compose from these components)
tech_stack:
  added: []
  patterns:
    - Astro server-rendered component, typed props from Phase 42 recap model
    - Status-aware color chips aligned with PortalScheduleSection.astro visual language
key_files:
  created:
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceSummary.astro
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceHistorySection.astro
  modified: []
decisions:
  - "PortalAttendanceSummary accepts summaryCounts + monthStart props (not the full recap model) — keeps the component focused and composable for the Phase 43 route page"
  - "PortalAttendanceHistorySection renders a minimal empty card when recentDays is empty — prevents crash without building Phase 44 exception-state system"
  - "fmtTs() derives hour:minute from ISO timestamptz at render time in Astro frontmatter — avoids client JS while keeping display aligned with device local time"
metrics:
  duration_minutes: 15
  completed_date: "2026-03-23"
  tasks_completed: 2
  files_created: 2
  files_modified: 0
---

# Phase 43 Plan 01: Portal Attendance Recap Surface Components Summary

Two shared Astro components for the employee portal attendance recap — month-summary chip grid and stacked recent-history cards — built directly on the Phase 42 typed recap model.

## What Was Built

### Task 1: PortalAttendanceSummary.astro

`src/components/portal/PortalAttendanceSummary.astro` — shared month-summary card surface.

- Accepts `summaryCounts: AttendanceSummaryCounts` and `monthStart: string` props
- Renders a responsive 3-column chip grid covering all 6 summary statuses: Hadir, Tidak Hadir, Sakit, Izin, Belum Pulang, Libur
- Color-coded chips (emerald/red/orange/sky/amber/gray) aligned with the existing portal visual language
- Indonesian employee-facing labels throughout
- Purely presentational — no data fetching or count derivation inside the component

### Task 2: PortalAttendanceHistorySection.astro

`src/components/portal/PortalAttendanceHistorySection.astro` — shared recent-history card list.

- Accepts `recentDays: PortalRecapDay[]` and `referenceDate: string` props
- Renders descending logical-day stacked cards in the same one-column pattern as `PortalScheduleSection.astro`
- Each card shows: date indicator column, status badge, shift name, outlet and schedule time range, named attendance timestamps (masuk/pulang/break/kembali), notes
- Status-aware color treatment across all 8 `AttendanceStatus` values
- Today's date is highlighted with the portal brand color (`#E91E8C`)
- Overnight shift label ("Selesai besok") preserved from the schedule pattern
- Minimal empty-list fallback card to prevent crash; no Phase 44 exception-state treatment

## Verification

`npm run check` passes for all Astro and portal source files. The only errors reported are pre-existing in `supabase/functions/` Deno Edge Function files which are outside the scope of this plan.

## Deviations from Plan

None — plan executed exactly as written.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | f3cbb4a | feat(43-01): create month-summary recap component |
| Task 2 | 3a7febc | feat(43-01): create recent-history recap component |

## Self-Check: PASSED

- `PortalAttendanceSummary.astro` exists at expected path: FOUND
- `PortalAttendanceHistorySection.astro` exists at expected path: FOUND
- Commits f3cbb4a and 3a7febc: FOUND in git log
- `summaryCounts` prop contract matches `AttendanceSummaryCounts` from `attendance-recap.ts`: FOUND
- `recentDays` prop contract matches `PortalRecapDay[]` from `attendance-recap.ts`: FOUND
