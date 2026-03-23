---
phase: 47-toolchain-contract-preflight-gates
plan: 03
subsystem: infra
tags: [kotlin, gradle, flutter, powershell, android]
requires:
  - phase: 47-02
    provides: tracked preflight lane and operator-facing fail-fast contract
provides:
  - Explicit v7.0 compatibility decision across build settings, docs, and preflight output
  - Lightweight drift checks for Kotlin, AGP, Gradle, Flutter, and Java contract strings
  - Clear operator prohibition on bypass flags and surprise upgrades during release hardening
affects: [signing, release-runbook, future-upgrade-spike]
tech-stack:
  added: [contract drift assertions]
  patterns: [version guardrails close to release entrypoints]
key-files:
  created: []
  modified: [android/settings.gradle.kts, tool/release_preflight.ps1, docs/android-release-contract.md]
key-decisions:
  - "Keep v7.0 pinned to Flutter 3.41.1, AGP 8.11.1, Gradle 8.14, Kotlin 1.9.25, and Java 21 JBR."
  - "Surface contract drift with lightweight string checks in the preflight lane rather than a larger version-management system."
patterns-established:
  - "Build comments, docs, and scripts must all express the same compatibility decision."
  - "Any future version change must update the tracked contract and guardrails together."
requirements-completed: [TOOL-02]
duration: 5min
completed: 2026-03-23
---

# Phase 47: Toolchain Contract & Preflight Gates Summary

**Pinned v7.0 compatibility contract with Kotlin 1.9.25 guardrails across build settings, docs, and preflight**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-23T21:09:00+08:00
- **Completed:** 2026-03-23T21:14:18+08:00
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Expanded `android/settings.gradle.kts` so the pinned Kotlin 1.9.25 line is explicitly a v7.0 release-hardening decision.
- Added preflight guard checks that surface drift from the tracked AGP, Gradle, Kotlin, Flutter, and Java contract before stage execution.
- Documented the v7.0 compatibility decision and the ban on `--android-skip-build-dependency-validation` in the operator-facing contract doc.

## Task Commits

1. **Task 1: Record the v7.0 compatibility decision in tracked docs and build comments** - `36c79c6` (docs)
2. **Task 2: Guard the canonical preflight lane against bypass flags and silent version drift** - `36c79c6` (docs/guardrail updates captured together)

**Plan metadata:** recorded in the final phase-completion docs update

## Files Created/Modified
- `android/settings.gradle.kts` - Explains why v7.0 intentionally stays on Kotlin 1.9.25.
- `tool/release_preflight.ps1` - Validates the tracked contract strings before analyze/test/release-only compile start.
- `docs/android-release-contract.md` - Records the pinned compatibility decision and forbids bypass flags in the canonical v7.0 lane.

## Decisions Made
- Kept the enforcement lightweight with string checks because Phase 47 is about contract clarity, not a full version-management system.
- Treated Flutter's Kotlin warning as an acknowledged release-hardening constraint, not permission for ad hoc operator upgrades.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The v7.0 compatibility line is now explicit and guarded wherever operators start release work.
- Later signing and runbook work can build on a pinned contract instead of relying on tribal knowledge.

---
*Phase: 47-toolchain-contract-preflight-gates*
*Completed: 2026-03-23*
