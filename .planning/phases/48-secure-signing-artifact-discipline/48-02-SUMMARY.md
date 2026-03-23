---
phase: 48-secure-signing-artifact-discipline
plan: 02
subsystem: infra
tags: [android, flutter, release, artifacts, powershell]
requires:
  - phase: 48-01
    provides: private upload-key signing contract and fail-fast release validation for release-capable tasks
provides:
  - tracked release_build.ps1 packaging entrypoint with check-only validation
  - versioned build/releases/android staging directory plus release-manifest.json contract
  - canonical signed .aab retention with opt-in signed .apk retention
affects: [48-03, 49-01, android-release-lane]
tech-stack:
  added: []
  patterns:
    - release packaging always gates through release_env and release_preflight before signed artifact work
    - retained Android artifacts are staged by release label instead of being read from transient AGP output folders
key-files:
  created:
    - tool/release_build.ps1
  modified:
    - docs/android-release-contract.md
key-decisions:
  - "Signed .aab remains the canonical retained Android release artifact; signed release .apk retention stays opt-in via -IncludeSideLoadApk."
  - "release_build.ps1 stages retained artifacts into build/releases/android/ABSENKOK-v<versionName>+<versionCode>/ and writes release-manifest.json instead of relying on AGP output naming."
patterns-established:
  - "Canonical artifact lane: release_env -> release_preflight -> signed appbundle -> optional retained apk -> staged manifest"
  - "Artifact retention contract: release directory name derives from tracked pubspec versionName+versionCode"
requirements-completed: [REL-02]
duration: 6 min
completed: 2026-03-23
---

# Phase 48 Plan 02: Artifact Discipline Summary

**Tracked Android packaging lane that validates itself with -CheckOnly, stages the canonical signed .aab into a versioned release directory, and only retains a signed release .apk when explicitly requested**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-23T13:52:10Z
- **Completed:** 2026-03-23T13:59:02Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added `tool/release_build.ps1` as the single tracked packaging entrypoint for the v7.0 Android artifact lane.
- Enforced the real build order `release_env -> release_preflight -> flutter build appbundle`, with optional retained APK staging only when `-IncludeSideLoadApk` is passed.
- Recorded the canonical artifact policy in `docs/android-release-contract.md`, including the staged release directory and `release-manifest.json`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add a single release entrypoint with preflight handoff, artifact staging, and a check-only mode** - `461900d` (feat)
2. **Task 2: Record the canonical artifact policy in the tracked release contract** - `2fa53a4` (docs)

## Files Created/Modified
- `tool/release_build.ps1` - validates the lane with `-CheckOnly`, gates real packaging behind preflight, stages retained artifacts into `build/releases/android`, and writes `release-manifest.json`.
- `docs/android-release-contract.md` - states that `.aab` is canonical, `.apk` retention is opt-in via `-IncludeSideLoadApk`, and the staged release directory is the tracked artifact contract.

## Decisions Made
- Signed `.aab` remains the canonical retained Android release artifact for v7.0; a signed release `.apk` is retained only when side-loading is intentionally requested.
- The packaging lane stages final retained artifacts into a versioned release directory and manifest rather than depending on AGP internal output names or folders.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The generic executor prompt referenced `$HOME/.claude/get-shit-done/bin/gsd-tools.cjs`, but this repo keeps the GSD tooling under `.claude/get-shit-done/bin/gsd-tools.cjs`; the metadata pass uses the workspace-local path.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- REL-02 is now satisfied in tracked code and documentation: the packaging contract can validate itself without cutting artifacts, and the retained artifact set is explicit.
- Phase 48-03 can layer split debug info retention and smoke verification on top of the staged release directory and manifest contract established here.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/48-secure-signing-artifact-discipline/48-02-SUMMARY.md`.
- Task commit `461900d` is present in git history.
- Task commit `2fa53a4` is present in git history.

---
*Phase: 48-secure-signing-artifact-discipline*
*Completed: 2026-03-23*
