---
phase: 46
plan: 01
subsystem: release-baseline
tags: [android, flutter, release, windows, gradle]
dependency_graph:
  requires: []
  provides: [canonical-c-flutter-release-baseline, v6.2-release-apk]
  affects: [46-02-version-alignment, android-local-tooling]
tech_stack:
  added: []
  patterns: [space-safe-flutter-sdk-alias, canonical-release-command]
key_files:
  created:
    - build/app/outputs/apk/release/ABSENKOK-v6.2.0.apk
  modified:
    - android/local.properties
decisions:
  - "Kept AGP 8.11.1, Gradle 8.14, Kotlin 1.9.25, and Android Studio JBR unchanged in baseline recovery; the path blocker cleared without a toolchain upgrade."
  - "Canonical release lane remains C:\\flutter\\bin\\flutter.bat build apk --release so the Windows host no longer depends on the spaced Flutter SDK path."
  - "android/local.properties remains gitignored by repo design, so task evidence is recorded in summary and empty task commits rather than force-tracking a machine-local file."
metrics:
  duration_minutes: 25
  completed_date: "2026-03-23"
  tasks_completed: 2
  files_changed: 2
---

# Phase 46 Plan 01: Release Baseline Recovery Summary

**One-liner:** Space-safe `C:\flutter` release baseline that gets the pinned v6.2 Android APK through packaging again without changing the v7.0 toolchain contract or signing flow.

## What Was Built

Restored the canonical Windows release path for this checkout by pointing the Android loader at the existing `C:\flutter` junction instead of the spaced Flutter SDK path under the workspace. That removes the earlier native-assets/path truncation class of failure from the real release lane while keeping Java on Android Studio JBR and leaving AGP, Gradle, Kotlin, and signing behavior untouched.

With that baseline in place, the canonical command `C:\flutter\bin\flutter.bat build apk --release` now reaches Android packaging again and emits the current-version APK artifact for the pre-bump baseline.

## Key Changes

### android/local.properties
- Changed `flutter.sdk` from the spaced workspace SDK path to `C:\flutter`
- Kept `java.home=C:\\Program Files\\Android\\Android Studio\\jbr`
- Left version metadata untouched at `6.2.0 / 8012` because version alignment belongs to Plan 46-02

### Release verification
- Ran `C:\flutter\bin\flutter.bat build apk --release`
- Confirmed packaging artifact at `build/app/outputs/apk/release/ABSENKOK-v6.2.0.apk`
- Confirmed the path-truncation/native-assets failure described in research no longer blocks the release lane

## Verification

- Baseline check: `C:\flutter\bin\flutter.bat` exists and `android/local.properties` resolves `flutter.sdk` through `C:\flutter`
- Canonical release lane: `C:\flutter\bin\flutter.bat build apk --release` - passed
- Artifact check: `build/app/outputs/apk/release/ABSENKOK-v6.2.0.apk` exists (100,415,566 bytes; last write 2026-03-23T12:08:51Z)
- Git evidence: `git log --oneline --all --grep="46-01"` returns task commits

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `android/local.properties` is ignored by git**
- **Found during:** Task 1 (Restore a space-safe Flutter SDK baseline for release builds)
- **Issue:** The plan's machine-local baseline file is intentionally gitignored, so staging it would require force-tracking host-specific SDK paths.
- **Fix:** Kept the local baseline change in place for the executing checkout and recorded the task outcome through empty task commits plus this summary instead of changing repo tracking rules.
- **Files modified:** android/local.properties
- **Verification:** Canonical release build passed with the updated local baseline.
- **Committed in:** `4449d4e`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope creep. The baseline is restored for this checkout, and repo tracking rules remain unchanged for machine-local Android config.

## Issues Encountered

- The first canonical rebuild advanced past the old path blocker but failed once at `:app:compressReleaseAssets` on `FlutterIconsax.ttf.jar`. Running `gradlew.bat app:compressReleaseAssets --stacktrace` succeeded cleanly, and the subsequent rerun of `C:\flutter\bin\flutter.bat build apk --release` completed successfully with no code or dependency changes. The issue is treated as a transient asset-compression failure, not an active baseline blocker.

## Self-Check

- [x] `android/local.properties` resolves `flutter.sdk` through `C:\flutter`
- [x] `build/app/outputs/apk/release/ABSENKOK-v6.2.0.apk` exists on disk
- [x] Task 1 commit: `4449d4e`
- [x] Task 2 commit: `c5c851e`
- [x] Canonical release command passed without reopening toolchain or signing scope
- [x] Ready for Plan 46-02 version alignment
