---
phase: 38-employee-schedule-read-model
plan: "02"
subsystem: portal-website
tags: [portal, schedule, astro, typescript, server-side]
dependency_graph:
  requires: [38-01]
  provides: [portal-schedule-helper, portal-index-schedule-surface]
  affects: [portal-pages]
tech_stack:
  added: []
  patterns: [typed-server-helper, rpc-caller, business-timezone-helper]
key_files:
  created:
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/schedule.ts
  modified:
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/index.astro
decisions:
  - "getPortalReferenceDate() uses Asia/Makassar (WITA) via Intl.DateTimeFormat — centralised so a future timezone field replaces one function"
  - "loadPortalSchedule() derives todayAssignment and upcomingAssignments from one RPC dataset, not separate queries"
  - "Overnight (endsNextDay) rows stay on logical start day with a Selesai besok label — matches system noon rule"
  - "Empty-week state uses a simple placeholder; full UX state matrix deferred to Phase 39"
metrics:
  duration_minutes: 2
  completed_date: "2026-03-22"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 1
---

# Phase 38 Plan 02: Employee Schedule Read Model — Website Helper + Portal Page Summary

**One-liner:** Typed `loadPortalSchedule()` Astro server helper plus a live `Jadwal hari ini` / current-week surface on `/portal` replacing the Phase 37 placeholder.

## What Was Built

### Task 1 — Typed server-side portal schedule helper
`src/lib/portal/schedule.ts` is the single server-side entry point for portal schedule loading.

Key exports:
- `PortalScheduleEntry` — normalized schedule row (logicalDate, outlet, shiftName, start/end times, endsNextDay, isDayOff)
- `PortalScheduleModel` — full result model (employee, referenceDate, todayAssignment, weekAssignments, upcomingAssignments)
- `PortalScheduleResult` — typed union (ok | unauthenticated | no_mapping | rpc_error | no_assignments)
- `getPortalReferenceDate()` — derives current business-local date in Asia/Makassar timezone via `Intl.DateTimeFormat`
- `loadPortalSchedule(Astro)` — resolves employee identity via `resolvePortalEmployee()`, passes one explicit `reference_date` to `get_portal_schedule_week`, normalizes rows, and derives today and upcoming from one dataset

Security boundary: employee ID is never accepted from page params, form fields, or query strings. The RPC resolves identity from `auth.uid()`.

### Task 2 — Portal home schedule surface
`src/pages/portal/index.astro` now renders real schedule data:
- Identity card preserved from Phase 37
- "Jadwal hari ini" section: active shift card (outlet, shift label, HH:MM–HH:MM, Selesai besok marker for overnight rows) or Libur card or "tidak ada jadwal" placeholder
- "Minggu ini" section: ordered list of all week assignments with today highlighted in brand pink; each row shows weekday, date, shift name, times, overnight marker, and outlet
- Empty week state: simple placeholder card (full UX state matrix reserved for Phase 39)
- Blocked-account path (no_mapping / rpc_error) preserved from Phase 37

## Commits

| Task | Commit | Files |
|------|--------|-------|
| 1 | b19859d | src/lib/portal/schedule.ts (created) |
| 2 | 3f91f0b | src/pages/portal/index.astro (updated) |

## Verification

- `astro check`: 0 errors, 0 warnings after Task 1
- `astro build`: Complete, all server entrypoints bundled after Task 2

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `src/lib/portal/schedule.ts` exists: confirmed
- `src/pages/portal/index.astro` contains `loadPortalSchedule` and `Jadwal hari ini`: confirmed
- Commits b19859d and 3f91f0b exist in git log: confirmed
