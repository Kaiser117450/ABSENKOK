---
phase: 49-release-runbook-acceptance
plan: 02
subsystem: infra
tags: [android, release, powershell, smoke, acceptance]
requires:
  - phase: 49-release-runbook-acceptance
    provides: tracked local Android release runbook for the v7.0 APK-first lane
provides:
  - smoke-verified APK-first release record for ABSENKOK-v7.0.0+8013
  - accepted Phase 49 evidence for OPS-01
  - PowerShell 5.1-safe release helper behavior for adb smoke verification
affects: [v7.0-closeout, android-release-lane, ops]
tech-stack:
  added: []
  patterns:
    - keep the tracked release lane truthful on Windows PowerShell 5.1 instead of relying on ad hoc shell workarounds
    - record debug-artifact status explicitly whether the final release is non-obfuscated or obfuscated
key-files:
  created:
    - .planning/phases/49-release-runbook-acceptance/49-ACCEPTANCE.md
    - .planning/phases/49-release-runbook-acceptance/49-02-SUMMARY.md
  modified:
    - tool/release_build.ps1
    - docs/android-release-contract.md
    - docs/android-release-runbook.md
    - .planning/phases/49-release-runbook-acceptance/49-VALIDATION.md
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md
    - .planning/STATE.md
key-decisions:
  - "Phase 49 acceptance is satisfied by the documented APK-first helper lane when `tool/release_build.ps1 -SmokeVerify` produces a passed smoke record beside the staged APK."
  - "The same helper lane can be promoted to the final distributable build with `-Obfuscate`, and the manifest must record symbol retention truthfully for whichever mode is used."
patterns-established:
  - "Windows PowerShell 5.1 smoke lane: process-based adb execution captures stdout and stderr without aborting on harmless monkey banner output."
  - "Release manifest truth model: debug artifact status is explicit instead of inferred from directory existence alone."
requirements-completed:
  - OPS-01
duration: 78 min
completed: 2026-03-25
---

# Phase 49 Plan 02: Release Acceptance Summary

**The tracked local APK-first release runbook now reproduces a smoke-verified v7.0 release record on this machine without bypass flags**

## Performance

- **Duration:** 78 min
- **Started:** 2026-03-24T23:10:00+08:00
- **Completed:** 2026-03-25T00:28:45+08:00
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Confirmed the local signing bootstrap and `adb` target requirements, then ran the documented `powershell.exe` helper chain through `tool/release_build.ps1 -SmokeVerify`.
- Produced the accepted release record at `build/releases/android/ABSENKOK-v7.0.0+8013/` with the canonical staged APK, `release-manifest.json`, `smoke-check.txt`, and `mapping.txt`.
- Recorded a passing smoke run for device `V8X8ROMVSWVKIVW8`; the manifest now shows `smokeVerification.status = passed`.
- Closed the remaining PowerShell 5.1 helper drift in `tool/release_build.ps1` so `adb` execution, scalar-versus-array handling, dirty git metadata capture, and debug-artifact recording are truthful under the operator shell this milestone documents.

## Post-Acceptance Release Finalization

- Re-ran the same release lane as `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -SmokeVerify -Obfuscate` so the final distributable v7.0 artifact is obfuscated.
- Restaged `build/releases/android/ABSENKOK-v7.0.0+8013/` with `debugArtifacts.obfuscationEnabled = true`, `debugArtifacts.splitDebugInfoStatus = retained`, three Dart symbol files, and `mapping.txt`.
- Uploaded the staged canonical APK to GitHub Release `v7.0.0` as `ABSENKOK-v7.0.0+8013.apk` using `gh release upload` fallback after the app automation could not read the local artifact path directly.

## Files Created/Modified

- `.planning/phases/49-release-runbook-acceptance/49-ACCEPTANCE.md` - final acceptance evidence for the successful Phase 49 run.
- `.planning/phases/49-release-runbook-acceptance/49-02-SUMMARY.md` - closeout summary for the acceptance plan.
- `.planning/phases/49-release-runbook-acceptance/49-VALIDATION.md` - validation status moved to approved with green checks.
- `.planning/ROADMAP.md` - Phase 49 marked 2/2 complete and milestone moved to ready-for-closeout.
- `.planning/REQUIREMENTS.md` - `OPS-01` marked complete; debug-artifact requirement wording updated to match the real release helper behavior.
- `.planning/STATE.md` - milestone state advanced to ready for closeout with 5/5 phases complete.
- `docs/android-release-contract.md` - release contract now explains both the accepted non-obfuscated `not-generated` case and the final obfuscated retained-symbol path.
- `docs/android-release-runbook.md` - operator runbook now documents the obfuscated publication lane and the GitHub upload fallback.
- `tool/release_build.ps1` - acceptance-blocker fixes for Git metadata capture, PowerShell 5.1 native command handling, smoke verification robustness, and the later `-Obfuscate` release lane.

## Decisions Made

- Keep the canonical release lane on `powershell.exe` and fix the helper to match that shell instead of moving the runbook to a different shell contract.
- Treat debug-artifact truth as part of the contract: non-obfuscated runs may record `not-generated`, while the final published obfuscated build must retain symbol files.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed PowerShell 5.1 smoke verification assumptions inside `tool/release_build.ps1`**
- **Found during:** Task 2 acceptance execution
- **Issue:** The documented lane exposed helper bugs under Windows PowerShell 5.1: scalar `.Count` assumptions, Git stderr aborts in a dirty worktree, and native `adb` stderr from `monkey` being promoted into terminating errors.
- **Fix:** Normalized array handling, switched Git metadata capture to `cmd.exe`, and replaced direct native-command capture with process-based stdout/stderr handling for ADB smoke commands.
- **Verification:** Re-ran the full `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -SmokeVerify` lane successfully with `smokeVerification.status = passed`.

**2. [Rule 3 - Blocking] Corrected the release contract for non-obfuscated split-debug-info output**
- **Found during:** Task 2 acceptance execution
- **Issue:** Flutter emitted no split-debug-info files for the non-obfuscated v7.0 release build, so requiring populated `symbols/` output would have made the runbook lie about the real artifact behavior.
- **Fix:** Staged the `symbols/` directory consistently, recorded `debugArtifacts.splitDebugInfoStatus = not-generated` in the manifest when no files were emitted, and updated the contract and runbook text to match that truth.
- **Verification:** Final manifest records `splitDebugInfoStatus = not-generated` while the acceptance run still passes.

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both fixes were required to make the documented Phase 49 operator lane truthful and reproducible on the supported local shell.

## Issues Encountered

- The first smoke rerun stopped because the device temporarily disappeared from `adb devices`; reconnecting the target resolved the operator-side blocker.
- Flutter 3.41.1 still warns that Kotlin 1.9.25 will lose support in a future cycle. That warning remains tracked technical debt, not a v7.0 release blocker.

## User Setup Required

None remaining for Phase 49. The acceptance run completed with the local signing bootstrap and Android target already in place.

## Next Phase Readiness

- `OPS-01` is now proven by a real local runbook execution.
- The v7.0 milestone implementation is complete and ready for milestone closeout.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/49-release-runbook-acceptance/49-02-SUMMARY.md`.
- Acceptance evidence exists at `.planning/phases/49-release-runbook-acceptance/49-ACCEPTANCE.md`.
- `build/releases/android/ABSENKOK-v7.0.0+8013/release-manifest.json` records `smokeVerification.status = passed`.
- `build/releases/android/ABSENKOK-v7.0.0+8013/smoke-check.txt` records install and launch evidence for the staged APK.
- GitHub Release `v7.0.0` contains the staged `ABSENKOK-v7.0.0+8013.apk` asset with the same SHA-256 digest recorded in the manifest.

---
*Phase: 49-release-runbook-acceptance*
*Completed: 2026-03-25*
