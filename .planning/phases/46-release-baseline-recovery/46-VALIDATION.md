---
phase: 46
slug: release-baseline-recovery
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-23
---

# Phase 46 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | PowerShell metadata smoke checks plus the real Flutter Android release build |
| **Config file** | `pubspec.yaml`, `android/local.properties`, `android/app/build.gradle.kts` |
| **Quick run command** | `powershell -Command "Select-String -Path 'pubspec.yaml','android/local.properties','android/app/build.gradle.kts' -Pattern 'version: ','flutter.versionName','flutter.versionCode','outputFileName' | Measure-Object"` |
| **Full suite command** | `flutter build apk --release` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** run the metadata/path smoke check for the files touched by that task
- **After every plan wave:** run `flutter build apk --release`
- **Before final phase verification:** the full release build must reach Android packaging and emit the expected v7.0 artifact name
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 46-01-01 | 01 | 1 | BUILD-01 | blocker reproduction | `flutter build apk --release` | Existing | pending |
| 46-01-02 | 01 | 1 | BUILD-01 | release rebuild | `flutter build apk --release` | Existing | pending |
| 46-02-01 | 02 | 2 | BUILD-03 | metadata smoke | `powershell -Command "Select-String -Path 'pubspec.yaml','android/local.properties' -Pattern 'version: ','flutter.versionName','flutter.versionCode' | Measure-Object"` | Existing | pending |
| 46-02-02 | 02 | 2 | BUILD-03 | artifact-name smoke + release rebuild | `powershell -Command "Select-String -Path 'android/app/build.gradle.kts' -Pattern 'outputFileName' | Measure-Object"; flutter build apk --release` | Existing | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test framework or scaffold is required before execution.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The final APK filename reads as the active milestone artifact without opening planning docs | BUILD-03 | Human readability of the artifact label is a product/ops judgment, not just a regex check | After the successful build, open `build/app/outputs/apk/release/` and confirm the emitted filename visibly contains the intended v7.0 version string. |
| The documented baseline recovery path is repeatable from a fresh shell | BUILD-01 | A second shell/session catches hidden machine-state assumptions that one terminal run can miss | Open a fresh shell in the repo root, rerun the canonical release command recorded by the implementation, and confirm packaging still succeeds without extra manual patching. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or existing build/smoke coverage
- [ ] Sampling continuity: no 3 consecutive implementation tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
