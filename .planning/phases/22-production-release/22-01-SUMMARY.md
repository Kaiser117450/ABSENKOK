---
phase: 22-production-release
plan: 01
subsystem: release
tags: [release, apk, github-releases, v3.1]
dependency_graph:
  requires: [20-biometric-login, 21-badge-color-picker]
  provides: [v3.1-release-apk, github-release-v3.1]
  affects: [pubspec.yaml]
tech_stack:
  added: []
  patterns: [github-releases, proguard-obfuscation]
key_files:
  created:
    - build/app/outputs/apk/release/ABSENKOK-v3.1.0.apk
  modified:
    - pubspec.yaml
key_decisions:
  - APK path is build/app/outputs/apk/release/ (Gradle applicationVariants rename), not flutter-apk/
metrics:
  duration: 407s
  completed: "2026-03-18T05:50:11Z"
  tasks_completed: 3
  tasks_total: 3
---

# Phase 22 Plan 01: Production Release APK + GitHub Release Summary

v3.1 production APK built with ProGuard minification, resource shrinking, and Dart obfuscation; published to GitHub Releases with changelog covering biometric login, badge color picker, and security fixes.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Bump version and build release APK | f3ae234 | pubspec.yaml, ABSENKOK-v3.1.0.apk |
| 2 | Create GitHub Release with APK and changelog | (GitHub action) | GitHub Release v3.1 |
| 3 | Verify GitHub Release page | (auto-approved) | N/A |

## What Was Done

### Task 1: Version Bump + Release Build
- Updated pubspec.yaml from `1.1.0+8006` to `3.1.0+8007`
- Built release APK with `--release --obfuscate --split-debug-info`
- ProGuard minification and resource shrinking applied via build.gradle.kts
- APK produced at `build/app/outputs/apk/release/ABSENKOK-v3.1.0.apk` (58.5MB)
- Split debug info generated at `build/debug-info/`

### Task 2: GitHub Release
- Pushed version bump commit to origin/main
- Created GitHub Release v3.1 at https://github.com/Kaiser117450/ABSENKOK/releases/tag/v3.1
- Attached ABSENKOK-v3.1.0.apk as release asset
- Changelog describes: Biometric Login, Badge Color Picker, 17 Codex security patches

### Task 3: Verification (Auto-approved)
- Verified tag name: v3.1
- Verified asset count: 1 (ABSENKOK-v3.1.0.apk)
- Verified title: "v3.1 -- Biometric Login + Badge Color Picker"

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] APK output path differs from plan expectation**
- **Found during:** Task 1 verification
- **Issue:** Plan expected APK at `build/app/outputs/flutter-apk/ABSENKOK-v3.1.0.apk` but Gradle applicationVariants rename outputs to `build/app/outputs/apk/release/ABSENKOK-v3.1.0.apk`
- **Fix:** Used correct path for gh release upload
- **Files modified:** None (path adjustment only)

## Verification Results

- [x] pubspec.yaml contains `version: 3.1.0+8007`
- [x] Release APK exists with ProGuard + obfuscation applied
- [x] GitHub Release v3.1 exists with 1 APK asset attached
- [x] Release notes cover biometric login, badge color picker, and security fixes
- [x] `gh release view v3.1` returns tag v3.1 with ABSENKOK-v3.1.0.apk

## Self-Check: PASSED

All artifacts verified:
- ABSENKOK-v3.1.0.apk exists at build/app/outputs/apk/release/
- debug-info symbols exist
- Commit f3ae234 exists in git log
- pubspec.yaml contains version 3.1.0+8007
- GitHub Release v3.1 accessible via gh CLI
