---
phase: 30
slug: multi-outlet-admin-visibility
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 30 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) |
| **Config file** | `pubspec.yaml` → `dev_dependencies: flutter_test` |
| **Quick run command** | `flutter test test/phase_30_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/phase_30_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 30-01-01 | 01 | 1 | HLTH-03,04,SYNC-03 | manual | Visual inspection | N/A | ⬜ pending |
| 30-01-02 | 01 | 1 | HLTH-03 | grep | `grep -r "isKioskOffline\|> 30" lib/` | ❌ W0 | ⬜ pending |
| 30-01-03 | 01 | 1 | HLTH-04 | grep | `grep -r "batteryLevel.*< 20\|lowBattery" lib/` | ❌ W0 | ⬜ pending |
| 30-01-04 | 01 | 1 | SYNC-03 | grep | `grep -r "pendingSyncCount.*> 0" lib/` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements. No new test framework or Wave 0 stubs needed.*

Phase 30 is primarily UI presentation of existing data. Validation is through:
1. Grep-based acceptance criteria (verifying code patterns exist)
2. Manual visual inspection (verifying UI renders correctly on device)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Offline badge visible for >30min heartbeat | HLTH-03 | UI rendering requires device | 1. Open admin dashboard 2. Verify outlet with stale heartbeat shows "Offline" badge |
| Low battery icon shows for <20% | HLTH-04 | Visual indicator requires device | 1. Set test outlet battery to 15% 2. Verify warning icon appears |
| Pending sync count shows on dashboard | SYNC-03 | UI element requires device | 1. Set test outlet pending_sync_count to 3 2. Verify count displays |
| "Belum Terhubung" for null heartbeat | Edge case | New outlet without kiosk | 1. Create new outlet 2. Verify shows "Belum Terhubung" not "Offline" |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
