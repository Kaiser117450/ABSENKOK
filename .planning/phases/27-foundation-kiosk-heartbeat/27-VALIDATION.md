---
phase: 27
slug: foundation-kiosk-heartbeat
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-19
---

# Phase 27 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter test |
| **Config file** | test/ directory |
| **Quick run command** | `flutter test test/services/heartbeat_service_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/services/heartbeat_service_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 27-01-01 | 01 | 1 | HLTH-01 | migration | SQL column check via Supabase | ❌ W0 | ⬜ pending |
| 27-01-02 | 01 | 1 | HLTH-01 | unit | `flutter test test/services/heartbeat_service_test.dart` | ❌ W0 | ⬜ pending |
| 27-02-01 | 02 | 2 | HLTH-02 | unit | `flutter test test/services/heartbeat_service_test.dart` | ❌ W0 | ⬜ pending |
| 27-02-02 | 02 | 2 | SYNC-01 | unit | `flutter test test/services/heartbeat_service_test.dart` | ❌ W0 | ⬜ pending |
| 27-03-01 | 03 | 3 | SYNC-02 | manual | Run kiosk mode 15min, check Supabase row updated | manual | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/services/heartbeat_service_test.dart` — stubs for HLTH-01, HLTH-02, SYNC-01, SYNC-02
- [ ] Battery mock via `battery_plus` FakeBatteryPlatform or simple stub

*Existing infrastructure covers all other phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Heartbeat fires every 15 min in real kiosk mode | SYNC-02 | Timer.periodic requires real device runtime | Install APK, enter kiosk mode, wait 15 min, check `outlets.last_heartbeat_at` in Supabase dashboard |
| Battery level reflects real device charge | HLTH-02 | Cannot mock hardware battery accurately | Check reported value matches device battery % shown in status bar |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
