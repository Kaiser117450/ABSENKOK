---
phase: 59-pdf-portal-parity
plan: 02
subsystem: portal-ui
tags: [astro, portal, ui, payroll, parity]
requires:
  - phase: 59-01
    provides: typed portal parity schedule and recap loaders
provides:
  - band-first today schedule card
  - target-first week rows without legacy shift clock dependence
  - strict outcome recap cards with calm helper copy
affects: [portal-home, portal-attendance, payroll-parity]
tech-stack:
  added: []
  patterns: [band-first portal cards, target-first progress copy, calm strict-outcome recap surface]
key-files:
  created: []
  modified:
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalScheduleSection.astro
    - C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceHistorySection.astro
key-decisions:
  - "Made the band label and required-hours target the first visual layer on portal cards, with schedule timestamps kept tertiary."
  - "Rendered strict payroll outcomes as explicit labels with calm helper copy instead of leaking short tags into the employee portal."
  - "Left `PortalAttendanceSummary.astro` unchanged because the recap shell did not need an extra helper component to satisfy the approved Phase 59 UI contract."
patterns-established:
  - "Portal schedule cards now express progress using `Sudah berjalan`, `Sisa`, `Tercatat`, `Lebih`, and `Kurang` from the parity loader."
  - "Attendance history cards combine strictOutcomeLabel, band/required-hours context, worked-vs-target copy, and tertiary timestamps in one calm recap shell."
requirements-completed: [SCHED-04]
duration: resumed
completed: 2026-03-28
---

# Phase 59 Plan 02: Portal UI Parity Summary

**The employee portal now shows band-first, target-first schedule and attendance cards that match the strict payroll outcome meaning without reverting to shift-clock-first UI.**

## Performance

- **Duration:** resumed execution
- **Started:** 2026-03-28 (resumed from existing portal parity work)
- **Completed:** 2026-03-28T16:35:03.1657332+08:00
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments

- Rebuilt the today schedule card around band label, `Hari ini`, required-hours target, progress/comparison copy, strict outcome chip, and calm helper text.
- Reworked week rows so they show day, band, required-hours, and outlet context without reintroducing `startHour` or `endHour`.
- Updated recent attendance history cards to show strict outcome parity, required-hours context, worked-vs-target lines, and tertiary attendance timestamps.

## Task Commits

Atomic task commits were skipped for this execution because the repository and linked portal workspace already contained unrelated dirty changes. Changes were left uncommitted to avoid bundling user-owned diffs.

## Files Created/Modified

- `C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalScheduleSection.astro` - band-first today card and week list with required/progress wording
- `C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceHistorySection.astro` - strict outcome recap cards with calm helper copy and tertiary timestamps

## Decisions Made

- Kept the portal tone calm for active and fallback states even when the strict payroll outcome is explicit.
- Used the typed parity loader labels directly instead of inventing a second UI-only status mapping.
- Avoided adding any new portal tabs or dashboard chrome so the change stays inside the existing shell.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Dropped the unused summary-helper rewrite**
- **Found during:** Task 1
- **Issue:** `PortalAttendanceSummary.astro` was listed as an optional helper surface, but the approved UI contract was fully satisfied by the schedule and history cards without introducing more shared markup.
- **Fix:** Left `PortalAttendanceSummary.astro` unchanged and kept the parity copy inside the already-active surfaces.
- **Files modified:** none
- **Verification:** Portal schedule and history components contain the locked Phase 59 copy and parity fields without needing an extra helper layer.

---

**Total deviations:** 1 auto-fixed blocking issue
**Impact on plan:** No scope change. The optional helper component was unnecessary, so the implementation stayed smaller while meeting the approved contract.

## Issues Encountered

- `npm --prefix "C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website" run check` remains blocked by the same pre-existing Deno typing errors in `supabase/functions/create-admin-user/index.ts` and `supabase/functions/provision-employee-portal-user/index.ts`. The modified Astro portal components did not appear in the diagnostics.

## User Setup Required

None.

## Next Phase Readiness

- The portal surfaces now match the same band-first and strict-outcome language that the payroll PDF export uses.
- Admin recap and PDF export can reference the shared parity fixtures knowing the employee-facing portal copy already aligns with them.

---
*Phase: 59-pdf-portal-parity*
*Completed: 2026-03-28*
