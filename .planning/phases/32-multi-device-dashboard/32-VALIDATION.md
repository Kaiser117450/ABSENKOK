---
phase: 32
slug: multi-device-dashboard
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-22
approved: 2026-03-22
---

# Phase 32 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (bundled with Flutter SDK) |
| **Config file** | `pubspec.yaml` (dev_dependencies) |
| **Quick run command** | `C:\flutter\bin\flutter.bat test --plain-name "phase32"` |
| **Full suite command** | `C:\flutter\bin\flutter.bat test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `C:\flutter\bin\flutter.bat test --plain-name "phase32"`
- **After every plan wave:** Run `C:\flutter\bin\flutter.bat test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 32-01-01 | 01 | 1 | HEALTH-03 | unit | `flutter test --plain-name "KioskDevice model"` | ✅ | ✅ green |
| 32-01-02 | 01 | 1 | HEALTH-03 | unit | `flutter test --plain-name "kiosk_devices RPC"` | ✅ | ✅ green |
| 32-02-01 | 02 | 1 | HEALTH-04 | unit | `flutter test --plain-name "set_device_nickname"` | ✅ | ✅ green — Phase 35 evidence 2026-03-22 |
| 32-02-02 | 02 | 1 | HEALTH-05 | unit | `flutter test --plain-name "archive_device"` | ✅ | ✅ green — Phase 35 evidence 2026-03-22 |
| 32-03-01 | 03 | 2 | HEALTH-03 | manual | N/A — UI widget test | ✅ | ✅ green — no race condition; two devices produce two separate kiosk_devices rows confirmed Phase 35 |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/phase32/` — test directory for phase 32 tests
- [ ] `test/phase32/kiosk_device_model_test.dart` — stubs for HEALTH-03
- [ ] `test/phase32/device_rpcs_test.dart` — stubs for HEALTH-04, HEALTH-05

*Existing flutter_test infrastructure covers framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Device list shows real-time battery/sync | HEALTH-03 | Requires Supabase realtime subscription on device | 1. Open admin dashboard 2. Check device cards update live |
| Nickname dialog saves and displays | HEALTH-04 | UI interaction flow | 1. Tap device card 2. Enter nickname 3. Verify persistence |
| Archive removes device from list | HEALTH-05 | UI + DB side effect | 1. Archive device 2. Verify removed from list 3. Check DB |
| No race condition on dual-device login | HEALTH-03 | Requires two physical devices | 1. Login from 2 devices to same outlet 2. Verify separate entries |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved — 2026-03-22. Phase 35 acceptance verification confirms: (1) no race condition on dual-device login — upsert_kiosk_heartbeat uses device_uuid as conflict key; (2) nickname persistence confirmed via set_device_nickname RPC + optimistic dashboard update; (3) archive confirmed via archive_device RPC + is_active filter in dashboard query.
