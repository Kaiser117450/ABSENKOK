---
phase: 59-pdf-portal-parity
plan: 01
subsystem: portal-data
tags: [sql, astro, portal, payroll, parity]
requires: []
provides:
  - additive portal parity SQL wrappers for strict recap and schedule progress
  - typed portal schedule and attendance recap loaders with target/progress fields
  - locked overnight and fallback parity fixtures for portal and PDF follow-up work
affects: [portal-schedule, portal-attendance-recap, payroll-pdf, validation]
tech-stack:
  added: []
  patterns: [additive portal parity rpc, strict-outcome loader contract, shared parity fixture source]
key-files:
  created:
    - sql/phase_59_portal_pdf_parity_20260328.sql
    - .planning/phases/59-pdf-portal-parity/59-PARITY-FIXTURES.md
  modified:
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/schedule.ts
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap.ts
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap-presentation.ts
    - .planning/phases/59-pdf-portal-parity/59-VALIDATION.md
key-decisions:
  - "Kept the Phase 59 SQL additive-only and left rollout as a later user-approved step instead of coupling planning work to a live database mutation."
  - "Moved required-hours, progress, and strict outcome labels into the typed portal loaders so Astro components no longer reconstruct payroll meaning from shift clocks."
  - "Locked the overnight and no-schedule fallback fixtures in one phase-local document before touching the portal UI or payroll PDF path."
patterns-established:
  - "Portal loaders now normalize parity fields into requiredHoursLabel, workedDisplayLabel, comparisonDisplayLabel, shortTags, and helperCopy."
  - "Phase validation references one shared parity fixture file instead of duplicating overnight and fallback expectations per surface."
requirements-completed: [SCHED-04, REPORT-03]
duration: resumed
completed: 2026-03-28
---

# Phase 59 Plan 01: Portal Parity Contract Summary

**Additive portal parity SQL and typed Astro loaders now expose one strict, progress-aware contract for schedule and attendance recap surfaces.**

## Performance

- **Duration:** resumed execution
- **Started:** 2026-03-28 (resumed from existing portal parity work)
- **Completed:** 2026-03-28T16:35:03.1657332+08:00
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added the Phase 59 SQL draft with `get_portal_schedule_parity_overview(...)` and `get_portal_attendance_parity_recap(...)` wrappers over the strict recap foundation.
- Rewrote the portal schedule and attendance recap loaders to expose band, target, progress, strict outcome, short tag, and helper-copy fields directly.
- Created the shared parity fixture source and pointed Phase 59 validation back to it for overnight and fallback cases.

## Task Commits

Atomic task commits were skipped for this execution because the repository and linked portal workspace already contained unrelated dirty changes. Changes were left uncommitted to avoid bundling user-owned diffs.

## Files Created/Modified

- `sql/phase_59_portal_pdf_parity_20260328.sql` - additive portal parity RPCs and helper functions for band labels, strict outcome copy, and short tags
- `C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/schedule.ts` - typed parity schedule model and `get_portal_schedule_parity_overview` loader path
- `C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap.ts` - typed parity recap model and `get_portal_attendance_parity_recap` loader path
- `C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap-presentation.ts` - presentation helper that consumes canonical parity fields instead of re-deriving strict meaning
- `.planning/phases/59-pdf-portal-parity/59-PARITY-FIXTURES.md` - locked overnight and no-schedule fallback parity expectations
- `.planning/phases/59-pdf-portal-parity/59-VALIDATION.md` - validation checklist now references the shared parity fixtures

## Decisions Made

- Preserved employee scoping and `Asia/Makassar` business-date handling inside the parity loaders.
- Kept `attendance-recap-presentation.ts` as presentation-only logic so the strict payroll meaning stays sourced from SQL and loader normalization.
- Deferred any live SQL execution to a later explicit rollout step.

## Deviations from Plan

None. The SQL stayed additive-only, the loader contract moved to strict parity fields, and the shared fixture source was created exactly as planned.

## Issues Encountered

- `npm --prefix "C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website" run check` is still blocked by pre-existing Deno typing issues in `supabase/functions/create-admin-user/index.ts` and `supabase/functions/provision-employee-portal-user/index.ts`. The diagnostics did not point at the modified portal parity loaders.

## User Setup Required

- The SQL draft is ready for review but must not be executed against a live environment until the user explicitly approves the rollout.

## Next Phase Readiness

- Portal components can now render band-first and target-first UI from a stable parity DTO instead of clock-first legacy fields.
- The payroll PDF path can reuse the same overnight and fallback fixtures without inventing a second parity vocabulary.

---
*Phase: 59-pdf-portal-parity*
*Completed: 2026-03-28*
