---
phase: 47-toolchain-contract-preflight-gates
plan: 01
subsystem: infra
tags: [powershell, flutter, gradle, java]
requires:
  - phase: 46-release-baseline-recovery
    provides: canonical Windows release lane and v7.0 artifact/version baseline
provides:
  - Windows helper that resolves Java 21 JBR and the canonical C:\flutter lane
  - Tracked Android release contract document linked from the repo root
  - Explicit separation between tracked contract files and machine-local local.properties evidence
affects: [release-preflight, signing, runbook]
tech-stack:
  added: [PowerShell helper, operator-facing release contract doc]
  patterns: [explicit JAVA_HOME resolution, tracked release contract]
key-files:
  created: [tool/release_env.ps1, docs/android-release-contract.md]
  modified: [README.md]
key-decisions:
  - "Resolve Java from ABSENKOK_JAVA_HOME first, then fall back to Android Studio JBR at C:\\Program Files\\Android\\Android Studio\\jbr."
  - "Keep android/local.properties machine-local and move the shared contract into tracked scripts/docs."
patterns-established:
  - "Release commands on Windows start through tool/release_env.ps1 instead of trusting PATH Java."
  - "README points operators to the tracked contract before any release automation is introduced."
requirements-completed: [TOOL-01]
duration: 7min
completed: 2026-03-23
---

# Phase 47: Toolchain Contract & Preflight Gates Summary

**Windows release helper that pins Java 21 JBR and exposes the v7.0 Android toolchain contract from the repo root**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-23T20:55:00+08:00
- **Completed:** 2026-03-23T21:02:04+08:00
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added `tool/release_env.ps1` as the tracked Windows entrypoint for Java 21 JBR and `C:\flutter\bin\flutter.bat`.
- Published `docs/android-release-contract.md` with the pinned v7.0 baseline and `-CheckOnly` verification flow.
- Added a repo-root README pointer so another operator can discover the contract without opening planning files.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add a tracked PowerShell helper for the supported release runtime** - `dceeb98` (feat)
2. **Task 2: Publish the v7.0 release contract where operators will actually find it** - `c6e59bd` (docs)

**Plan metadata:** recorded in the final phase-completion docs update

## Files Created/Modified
- `tool/release_env.ps1` - Resolves Java 21 JBR, exports `JAVA_HOME`, and verifies the canonical Flutter CLI.
- `docs/android-release-contract.md` - Tracks the supported release runtime and operator verification command.
- `README.md` - Links repo-root operators to the tracked Android release contract.

## Decisions Made
- Used `ABSENKOK_JAVA_HOME` as an override so the helper stays Windows-specific but can still support non-default Android Studio installs.
- Kept the tracked contract out of `android/local.properties` because that file is machine-local by design.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `java -version` writes to stderr in PowerShell, so `tool/release_env.ps1` captures the output through `cmd.exe` before parsing the Java major version.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 47 now has a tracked answer for Java and Flutter runtime selection.
- The repo is ready for a fail-fast preflight lane that inherits the same contract.

---
*Phase: 47-toolchain-contract-preflight-gates*
*Completed: 2026-03-23*
