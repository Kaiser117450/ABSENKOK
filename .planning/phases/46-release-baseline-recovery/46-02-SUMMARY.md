---
phase: 46
plan: 02
subsystem: release-versioning
tags: [android, flutter, release, versioning, gradle]
dependency_graph:
  requires: [46-01-release-baseline]
  provides: [v7-metadata-alignment, v7-release-apk]
  affects: [47-toolchain-contract, release-artifact-naming]
tech_stack:
  added: []
  patterns: [pubspec-version-source-of-truth, variant-versionName-derived-apk-name]
key_files:
  created:
    - build/app/outputs/apk/release/ABSENKOK-v7.0.0.apk
  modified:
    - pubspec.yaml
    - android/local.properties
decisions:
  - "Kept pubspec.yaml as the single version source of truth and let Flutter regenerate android/local.properties from the release build."
  - "Retained the existing outputFileName rule in android/app/build.gradle.kts because it already derives the APK filename from variant.versionName."
  - "Did not add post-build renaming or duplicate Gradle version literals; the rebuilt release lane now emits ABSENKOK-v7.0.0.apk directly."
metrics:
  duration_minutes: 12
  completed_date: "2026-03-23"
  tasks_completed: 2
  files_changed: 3
---

# Phase 46 Plan 02: Release Metadata Alignment Summary

**One-liner:** v7.0 version alignment driven from `pubspec.yaml`, with regenerated Android metadata and a release APK that now advertises `ABSENKOK-v7.0.0.apk` on the restored baseline lane.

## What Was Built

Updated the Flutter source-of-truth version from `6.2.0+8012` to `7.0.0+8013` in `pubspec.yaml`. After rebuilding the same `C:\flutter` release lane restored in Plan 46-01, Flutter regenerated `android/local.properties` to `flutter.versionName=7.0.0` and `flutter.versionCode=8013`.

The existing APK naming rule in `android/app/build.gradle.kts` required no changes. Because it already derives the filename from `variant.versionName`, the rebuilt release output now lands at `build/app/outputs/apk/release/ABSENKOK-v7.0.0.apk` without any extra rename script or hardcoded duplicate version string.

## Key Changes

### pubspec.yaml
- Changed `version: 6.2.0+8012` to `version: 7.0.0+8013`
- Preserved every dependency constraint and SDK bound unchanged
- Kept Flutter as the only version source of truth for Android metadata

### Android metadata and artifact output
- Rebuilt via `C:\flutter\bin\flutter.bat build apk --release`
- Confirmed `android/local.properties` now contains:
  - `flutter.versionName=7.0.0`
  - `flutter.versionCode=8013`
- Confirmed release artifact path: `build/app/outputs/apk/release/ABSENKOK-v7.0.0.apk`
- Confirmed `android/app/build.gradle.kts` still derives `outputFileName` from `variant.versionName`

## Verification

- Source version check: `pubspec.yaml` contains `version: 7.0.0+8013`
- Android metadata check: `android/local.properties` contains `flutter.versionName=7.0.0` and `flutter.versionCode=8013`
- Artifact check: `build/app/outputs/apk/release/ABSENKOK-v7.0.0.apk` exists (100,415,562 bytes; last write 2026-03-23T12:17:03Z)
- Naming rule check: `android/app/build.gradle.kts` still sets `output.outputFileName = "ABSENKOK-v${variant.versionName}.apk"`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `android/local.properties` is still machine-local**
- **Found during:** Task 2 (Refresh Android metadata and verify the v7.0-named release artifact)
- **Issue:** The regenerated Android metadata lives in `android/local.properties`, which remains gitignored and cannot serve as a tracked repo contract by itself.
- **Fix:** Used the real release build to regenerate and verify the local metadata for this checkout, then recorded the proof in summary and planning state while leaving tracked contract work for Phase 47.
- **Files modified:** android/local.properties
- **Verification:** `flutter.versionName=7.0.0`, `flutter.versionCode=8013`, and `ABSENKOK-v7.0.0.apk` all matched after the rebuild.
- **Committed in:** `d7ba32a`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope creep. v7.0 metadata alignment is complete on the restored release lane, and the remaining tracked machine-contract work stays correctly deferred to Phase 47.

## Issues Encountered

None.

## Self-Check

- [x] `pubspec.yaml` is `7.0.0+8013`
- [x] `android/local.properties` regenerated to `7.0.0 / 8013`
- [x] `build/app/outputs/apk/release/ABSENKOK-v7.0.0.apk` exists on disk
- [x] Task 1 commit: `aec0324`
- [x] Task 2 commit: `d7ba32a`
- [x] Ready to treat Phase 46 as complete and move to Phase 47
