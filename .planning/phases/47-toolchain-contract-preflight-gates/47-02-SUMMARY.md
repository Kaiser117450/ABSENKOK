---
phase: 47-toolchain-contract-preflight-gates
plan: 02
subsystem: infra
tags: [powershell, flutter, gradle, analyze, test]
requires:
  - phase: 47-01
    provides: tracked release environment helper and operator-facing contract doc
provides:
  - One release preflight command that runs analyze, test, and release-only compile in order
  - Proof that the current repo fails before packaging/signing on analyzer debt
  - Operator documentation for the fail-fast expectations of the preflight lane
affects: [compatibility-contract, signing, runbook]
tech-stack:
  added: [PowerShell preflight lane]
  patterns: [fail-fast stage runner, release-only compile gate]
key-files:
  created: [tool/release_preflight.ps1]
  modified: [docs/android-release-contract.md]
key-decisions:
  - "Use :app:compileReleaseSources as the release-only compile stage instead of assembleRelease or bundleRelease."
  - "Keep the current analyze/test failures visible and documented instead of weakening the lane to make it pass."
patterns-established:
  - "Release preflight always enters through tool/release_env.ps1 before Flutter or Gradle commands run."
  - "Preflight stops on the first red stage and never continues to packaging or signing tasks."
requirements-completed: [BUILD-02]
duration: 11min
completed: 2026-03-23
---

# Phase 47: Toolchain Contract & Preflight Gates Summary

**Fail-fast release preflight lane that stops at analyzer debt before any release packaging or signing step**

## Performance

- **Duration:** 11 min
- **Started:** 2026-03-23T21:02:30+08:00
- **Completed:** 2026-03-23T21:13:38+08:00
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added `tool/release_preflight.ps1` as the single tracked lane for `flutter analyze`, `flutter test`, and `:app:compileReleaseSources`.
- Verified the current checkout fails in `flutter analyze` with exit code `1` and 152 issues before any packaging/signing step begins.
- Documented the preflight lane, fail-fast expectations, and observed red-state behavior in the tracked release contract.

## Task Commits

1. **Task 1: Add a single preflight entrypoint for analyze, test, and release-only compile** - `982ed4d` (build)
2. **Task 2: Prove the preflight lane fails before signing on the current red repo state** - `982ed4d` (build/docs evidence captured with the lane introduction)

**Plan metadata:** recorded in the final phase-completion docs update

## Files Created/Modified
- `tool/release_preflight.ps1` - Runs analyze, test, and `:app:compileReleaseSources` with clear stage banners and fail-fast exit handling.
- `docs/android-release-contract.md` - Documents the preflight entrypoint and the observed fail-fast result on the current red repo state.

## Decisions Made
- Chose `:app:compileReleaseSources` because it exercises release-only compilation without entering package/sign tasks.
- Preserved the repo's current analyzer/test failures as signal instead of adding bypasses or scope-creep fixes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Operator output] Switched from Write-Error to a plain stop message**
- **Found during:** Task 2 (live preflight verification)
- **Issue:** `Write-Error` produced a PowerShell stack trace after the intended fail-fast stop, which was noisy for operators.
- **Fix:** Changed the preflight lane to print a plain stop message and return the failing stage exit code directly.
- **Files modified:** `tool/release_preflight.ps1`
- **Verification:** Re-ran the preflight lane and confirmed it still stopped at `Flutter analyze` with exit code `1`.
- **Committed in:** `982ed4d` (part of task commit)

---

**Total deviations:** 1 auto-fixed (operator output)
**Impact on plan:** Improved the operator-facing failure mode without expanding scope beyond the planned preflight lane.

## Issues Encountered

- The first live preflight run exceeded the initial command timeout, but the longer rerun confirmed the lane stops at `Flutter analyze` before package/sign tasks.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The repo now has a deterministic preflight lane that exposes red checks early.
- Phase 47 can safely add compatibility guardrails without changing the underlying build versions.

---
*Phase: 47-toolchain-contract-preflight-gates*
*Completed: 2026-03-23*
