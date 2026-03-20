---
phase: 31
slug: device-identity-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 31 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Dart) |
| **Config file** | `pubspec.yaml` (dev_dependencies: flutter_test) |
| **Quick run command** | `flutter test test/device_identity_service_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/device_identity_service_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 31-01-01 | 01 | 1 | HEALTH-01 | unit | `flutter test test/device_identity_service_test.dart` | ❌ W0 | ⬜ pending |
| 31-01-02 | 01 | 1 | HEALTH-01 | manual | Session persistence across logout | N/A | ⬜ pending |
| 31-02-01 | 02 | 1 | HEALTH-02 | SQL | `SELECT * FROM kiosk_devices` after heartbeat | ❌ W0 | ⬜ pending |
| 31-02-02 | 02 | 1 | HEALTH-02 | manual | Admin dashboard still shows outlet health during bridge | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/device_identity_service_test.dart` — stubs for HEALTH-01 (UUID generation, persistence, upgrade)
- [ ] SQL migration verified on Supabase branch — stubs for HEALTH-02

*Existing flutter_test infrastructure covers framework requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| UUID persists across kiosk logout/re-setup | HEALTH-01 | Requires SharedPreferences lifecycle across sessions | 1. Setup kiosk 2. Note device UUID from debug log 3. Logout 4. Re-setup same outlet 5. Verify same UUID in debug log |
| Admin dashboard shows outlet health during bridge | HEALTH-02 | Requires running app + Supabase together | 1. Deploy new code 2. Let heartbeat fire 3. Check admin dashboard "Status Kiosk" still shows battery/online status |
| Heartbeat upserts to kiosk_devices | HEALTH-02 | Requires production-like Supabase | 1. Run app with new code 2. Wait for heartbeat 3. Query `SELECT * FROM kiosk_devices` — row should exist |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
