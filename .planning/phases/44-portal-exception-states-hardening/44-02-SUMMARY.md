---
phase: 44-portal-exception-states-hardening
plan: "02"
subsystem: portal-web
tags: [portal, recap, attendance, exception-states, presentation-helper]
dependency_graph:
  requires: [44-01]
  provides: [ATTN-05, PORT-03]
  affects: [PortalAttendanceHistorySection.astro]
tech_stack:
  added: []
  patterns: [shared-presentation-helper, tone-driven-styling]
key_files:
  created: []
  modified:
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceHistorySection.astro
decisions:
  - "Replaced per-status getStatusLabel/getStatusStyle ad hoc functions with tone-driven getToneStyle() map sourced from the shared getRecapDayPresentation() helper — single source of exception taxonomy"
  - "Follow-up chip only rendered when needsFollowUp=true — belum_masuk and sedang_bekerja (accent tone, today informational) receive no chip"
  - "supportingCopy shown for all non-null copy including informational accent states — employees understand sedang_bekerja without alarming them"
  - "warning tone cards always use amber-50 background regardless of today flag — follow-up gaps must be visually prominent on any date"
metrics:
  duration_minutes: 7
  completed_date: "2026-03-23"
  tasks_completed: 2
  files_modified: 1
---

# Phase 44 Plan 02: History Section Follow-Up Hardening Summary

**One-liner:** Routed history card badges, tones, follow-up chips, and supporting copy through the shared `getRecapDayPresentation()` helper so follow-up gaps are explicit while current-day informational states stay calm.

## What Was Built

`PortalAttendanceHistorySection.astro` was hardened in two tasks:

**Task 1 — Route badges and tone through shared helper**

The component previously used two ad hoc functions (`getStatusLabel`, `getStatusStyle`) with per-status switch statements that duplicated exception semantics already defined in `attendance-recap-presentation.ts`. Both functions were removed. The component now calls `getRecapDayPresentation(day.attendanceStatus)` to obtain `label`, `tone`, `needsFollowUp`, `followUpLabel`, and `supportingCopy`. A new `getToneStyle(tone, today)` map translates the `RecapDayTone` value to Tailwind colour tokens, keeping the colour logic in one place.

**Task 2 — Follow-up chip and supporting copy**

- `belum_pulang` and `tidak_hadir` (tone: warning) render an amber chip with a warning triangle icon and the `followUpLabel` string from the helper. This makes the action gap explicit without adding any buttons or workflow links.
- All statuses with non-null `supportingCopy` render a one-sentence explanation below the timestamps. For follow-up gaps this uses the `style.meta` (amber) colour; for informational accent states it uses muted `text-gray-400` so the employee is informed but not alarmed.
- `sedang_bekerja` and `belum_masuk` have `needsFollowUp: false` — no chip, no warning styling, just the accent (pink) tone and their respective supporting copy.

## Verification

- `npm run check` — ok (no errors)
- Pattern match for `needsFollowUp`, `followUpLabel`, `supportingCopy` — 6 matches confirmed in component

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] `PortalAttendanceHistorySection.astro` modified (confirmed by `npm run check`)
- [x] Commit `40791e5` exists and contains the file change
- [x] `needsFollowUp`, `followUpLabel`, `supportingCopy` all present in component (6 matches)

## Self-Check: PASSED
