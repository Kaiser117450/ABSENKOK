---
phase: 49-release-runbook-acceptance
plan: 01
subsystem: infra
tags: [android, release, powershell, runbook, docs]
requires:
  - phase: 48.1-apk-first-release-artifact-alignment
    provides: APK-first helper contract, optional bundle retention, and PowerShell 5.1 smoke-lane truth
provides:
  - tracked local Android release runbook for the v7.0 APK-first lane
  - explicit private signing bootstrap placeholders for operators
  - release readiness checklist aligned to the live helper output
affects: [49-02, android-release-lane, ops]
tech-stack:
  added: []
  patterns:
    - document the tracked helper chain directly instead of rephrasing it from memory
    - keep PowerShell 5.1 as the operator-facing shell contract
key-files:
  created:
    - docs/android-release-runbook.md
  modified: []
key-decisions:
  - "The local release runbook stays on `powershell.exe` and names the helper order exactly as implemented in the repo."
  - "Private signing bootstrap is documented via placeholders only; the real keystore and `android/key.properties` stay machine-local and untracked."
patterns-established:
  - "Operator sequence: release_env check -> release_preflight -> release_build check-only -> release_build -SmokeVerify"
  - "Default release acceptance remains APK-first with optional bundle retention called out explicitly via `-IncludeAppBundle`."
requirements-completed: []
duration: 3 min
completed: 2026-03-23
---

# Phase 49 Plan 01: Release Runbook Summary

**Tracked local PowerShell release runbook for the v7.0 APK-first lane, aligned to the live helper contract and staged artifact record**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-23T23:36:30+08:00
- **Completed:** 2026-03-23T23:39:32+08:00
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Created `docs/android-release-runbook.md` as the operator-facing local release guide for the tracked APK-first Android lane.
- Documented the exact `powershell.exe` helper order, private signing placeholder schema, expected staged outputs, and release readiness checklist.
- Cross-checked the runbook against the live `tool/release_build.ps1 -CheckOnly -SmokeVerify` output so the doc now reflects the real release label, app package, ADB surface, and default `Bundle retention: omitted` state.

## Task Commits

Each task was committed atomically:

1. **Task 1: Draft the operator runbook with prerequisites, bootstrap placeholders, and exact command order** - `96e8c16` (docs)
2. **Task 2: Cross-check the runbook against the live helper contract and expected outputs** - `6295245` (docs)

## Files Created/Modified
- `docs/android-release-runbook.md` - documents the tracked local Android release flow, bootstrap placeholders, command order, expected staged outputs, and readiness checklist.

## Decisions Made
- Keep the runbook operator-facing and local only; CI/CD, GitHub Release publishing, and Play Store flow stay out of scope for Phase 49.
- Record the default lane as APK-first and make bundle retention explicitly optional through `-IncludeAppBundle`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Corrected PowerShell quoting in Phase 49 verification commands**
- **Found during:** Task 1 verification
- **Issue:** The planned `powershell -Command "..."` verification strings were vulnerable to outer-shell variable expansion, which would make future executor verification fail for the wrong reason.
- **Fix:** Rewrote the verification commands in `49-01-PLAN.md`, `49-02-PLAN.md`, and `49-VALIDATION.md` to use a single-quoted PowerShell command wrapper.
- **Files modified:** `.planning/phases/49-release-runbook-acceptance/49-01-PLAN.md`, `.planning/phases/49-release-runbook-acceptance/49-02-PLAN.md`, `.planning/phases/49-release-runbook-acceptance/49-VALIDATION.md`
- **Verification:** Re-ran the marker audit command successfully after the quoting fix.
- **Committed in:** `a97f207` (fix)

**2. [Rule 3 - Blocking] Kept `OPS-01` completion on the acceptance plan instead of the runbook-only plan**
- **Found during:** Wave 1 closeout review
- **Issue:** If `49-01` retained `requirements: [OPS-01]`, the standard execute-plan requirement sync would mark the phase requirement complete before the real acceptance run happened.
- **Fix:** Moved actual requirement completion responsibility to `49-02` by clearing `49-01` requirement completion.
- **Files modified:** `.planning/phases/49-release-runbook-acceptance/49-01-PLAN.md`
- **Verification:** Revalidated the updated plan structure with `gsd-tools verify plan-structure`.
- **Committed in:** `217ed77` (fix)

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both fixes improved execution truthfulness without changing scope. Wave 1 still delivered the planned runbook outcome.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required for the runbook-only plan.

## Next Phase Readiness
- `49-02` can now use the tracked runbook as its single operator source of truth.
- The next wave still requires human bootstrap: local `android/key.properties`, private upload keystore availability, and an `adb`-visible Android target.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/49-release-runbook-acceptance/49-01-SUMMARY.md`.
- Task commit `96e8c16` is present in git history.
- Task commit `6295245` is present in git history.

---
*Phase: 49-release-runbook-acceptance*
*Completed: 2026-03-23*
