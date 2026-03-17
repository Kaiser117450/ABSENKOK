---
phase: 20
slug: biometric-login
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-18
---

# Phase 20 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test (flutter_test) |
| **Config file** | `pubspec.yaml` (dev_dependencies: flutter_test) |
| **Quick run command** | `C:\flutter\bin\flutter.bat test test/biometric_test.dart` |
| **Full suite command** | `C:\flutter\bin\flutter.bat test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `C:\flutter\bin\flutter.bat test test/biometric_test.dart`
- **After every plan wave:** Run `C:\flutter\bin\flutter.bat test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 20-01-01 | 01 | 1 | AUTH-01 | unit | `flutter test test/biometric_test.dart` | ❌ W0 | ⬜ pending |
| 20-01-02 | 01 | 1 | AUTH-02 | unit | `flutter test test/biometric_test.dart` | ❌ W0 | ⬜ pending |
| 20-01-03 | 01 | 1 | AUTH-03 | unit | `flutter test test/biometric_test.dart` | ❌ W0 | ⬜ pending |
| 20-01-04 | 01 | 1 | AUTH-04 | unit | `flutter test test/biometric_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/biometric_test.dart` — stubs for AUTH-01, AUTH-02, AUTH-03, AUTH-04
- [ ] Ensure `local_auth` mockable via platform channel mocking

*Existing Flutter test infrastructure covers framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Fingerprint/face prompt appears on real device | AUTH-01 | BiometricPrompt requires real hardware | 1. Install on device with fingerprint. 2. Login once. 3. Close app. 4. Reopen — biometric prompt should appear. |
| Biometric cancel falls back to login form | AUTH-02 | Requires user interaction with system dialog | 1. Trigger biometric prompt. 2. Press Cancel. 3. Verify login form is shown. |
| Device with no biometric sensor skips setup | AUTH-04 | Requires device without biometric hardware | 1. Install on emulator with no fingerprint. 2. Login. 3. Verify no biometric prompt or toggle shown. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
