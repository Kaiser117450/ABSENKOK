---
phase: 28
slug: failure-surfaces-crash-reporting
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 28 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK built-in, already in dev_dependencies) |
| **Config file** | none — standard `flutter test` invocation |
| **Quick run command** | `flutter test test/services/sentry_service_test.dart` |
| **Full suite command** | `flutter test test/` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/services/sentry_service_test.dart`
- **After every plan wave:** Run `flutter test test/`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 28-01-01 | 01 | 1 | FAIL-01 | manual-only | Manual: verify main.dart SentryFlutter.init structure | N/A | ⬜ pending |
| 28-01-02 | 01 | 1 | FAIL-02 | unit | `flutter test test/services/sentry_service_test.dart` | ❌ W0 | ⬜ pending |
| 28-01-03 | 01 | 1 | FAIL-03 | unit | `flutter test test/services/sentry_service_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/services/sentry_service_test.dart` — stubs for FAIL-02 (beforeSend NFC filter) and FAIL-03 (captureBackgroundFailure throttle + scope)

*Existing flutter_test infrastructure covers framework needs. No additional framework install required.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SentryFlutter.init wraps runApp in appRunner | FAIL-01 | Framework entry point — cannot unit-test SentryFlutter.init without full SDK mocking | 1. Read main.dart, confirm SentryFlutter.init with appRunner wraps runApp. 2. Confirm DSN is gated by kReleaseMode. 3. Build release APK and verify no crash on startup. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
