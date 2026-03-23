---
phase: 48-secure-signing-artifact-discipline
plan: 03
subsystem: infra
tags: [android, flutter, release, symbols, smoke-verification, powershell]
requires:
  - phase: 48-02
    provides: staged release directory plus release-manifest.json for retained Android artifacts
provides:
  - retained split-debug-info symbols and optional mapping.txt in the versioned release directory
  - SmokeVerify mode with adb install/launch evidence recorded in smoke-check.txt
  - tracked release contract that blocks distribution until symbols and smoke evidence are present
affects: [49-01, 49-02, android-release-lane]
tech-stack:
  added: []
  patterns:
    - release builds retain split-debug-info under the same versioned directory as the signed artifacts
    - smoke verification uses the signed release APK path and records evidence back into the staged release manifest bundle
key-files:
  created: []
  modified:
    - tool/release_build.ps1
    - docs/android-release-contract.md
key-decisions:
  - "v7.0 retains Dart split-debug-info by default without enabling obfuscation."
  - "When smoke verification needs an APK but side-loading is not requested, release-manifest.json records apkRetentionState as smoke-only instead of silently treating the APK as distributable."
patterns-established:
  - "Release evidence bundle: canonical .aab + symbols/ + optional mapping.txt + smoke-check.txt under one versioned release directory"
  - "Check-only smoke validation: resolve adb, app package, APK plan, and evidence path without requiring an attached Android target"
requirements-completed: [REL-03]
duration: 11 min
completed: 2026-03-23
---

# Phase 48 Plan 03: Release Evidence Discipline Summary

**Versioned Android release bundles now retain split-debug-info plus optional R8 mapping output and can validate the smoke-verification lane that records install and launch evidence before distribution**

## Performance

- **Duration:** 11 min
- **Started:** 2026-03-23T14:03:00Z
- **Completed:** 2026-03-23T14:14:37Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Extended `tool/release_build.ps1` so signed release builds retain Dart symbols under `symbols/`, capture `mapping.txt` when present, and record those debug artifact paths in `release-manifest.json`.
- Added `-SmokeVerify` to the release lane, including `adb` discovery, app package resolution, and `smoke-check.txt` evidence capture for install and launch results.
- Updated `docs/android-release-contract.md` so v7.0 distribution now requires both retained symbols and smoke evidence inside the same staged release directory.

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend the release lane to retain Dart and Android symbol artifacts for each signed release** - `424cf87` (feat)
2. **Task 2: Add smoke-verification mode and record its evidence next to the signed release** - `a33b333` (feat)

## Files Created/Modified
- `tool/release_build.ps1` - retains split-debug-info and optional mapping output in the staged release directory, records debug artifact paths in the manifest, and adds the `-SmokeVerify` adb evidence lane.
- `docs/android-release-contract.md` - requires symbol retention plus `smoke-check.txt` before distribution and documents `-CheckOnly -IncludeSideLoadApk -SmokeVerify` as the smoke-lane contract check.

## Decisions Made
- Keep `--obfuscate` disabled for v7.0 and use `--split-debug-info` alone so release diagnosability improves without widening rollout risk.
- Treat smoke-only APK generation as explicit evidence, not distribution: the manifest marks `apkRetentionState: smoke-only` when `-SmokeVerify` needs an APK but `-IncludeSideLoadApk` is not requested.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The repo-local `gsd-tools` updated `ROADMAP.md`, `REQUIREMENTS.md`, and session continuity, but `state advance-plan`, `state update-progress`, `state record-metric`, and `state add-decision` still do not match the current `STATE.md` structure, so the current position, progress block, and new 48-03 decisions were reconciled manually.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- REL-03 is satisfied in tracked code and docs: the release lane now keeps its debugging artifacts and has a check-only smoke-verification contract.
- Phase 49 can focus on operator runbook and acceptance evidence rather than inventing new artifact or smoke-verification policy.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/48-secure-signing-artifact-discipline/48-03-SUMMARY.md`.
- Task commit `424cf87` is present in git history.
- Task commit `a33b333` is present in git history.

---
*Phase: 48-secure-signing-artifact-discipline*
*Completed: 2026-03-23*
