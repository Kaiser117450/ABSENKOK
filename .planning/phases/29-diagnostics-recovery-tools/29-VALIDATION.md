---
phase: 29
slug: diagnostics-recovery-tools
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 29 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) |
| **Config file** | `pubspec.yaml` (dev_dependencies: flutter_test) |
| **Quick run command** | `flutter test test/phase29/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/phase29/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 29-01-01 | 01 | 1 | SYNC-04 | manual | visual inspection | N/A | ⬜ pending |
| 29-01-02 | 01 | 1 | RECV-01 | manual | visual inspection | N/A | ⬜ pending |
| 29-01-03 | 01 | 1 | RECV-02 | unit | `flutter test test/phase29/force_sync_test.dart` | ❌ W0 | ⬜ pending |
| 29-01-04 | 01 | 1 | RECV-03 | manual | visual inspection | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/phase29/force_sync_test.dart` — stubs for RECV-02 (SyncService.syncPendingLogs called on force sync)

*Existing infrastructure (SqliteService, SyncService) already has the backend logic. UI-heavy phase means most verification is manual.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Sync indicator visible when pending > 0 | SYNC-04 | UI visual state | 1. Insert test pending_log into SQLite. 2. Navigate to kiosk idle. 3. Verify indicator appears with correct count. |
| Diagnostics screen accessible via long-press | RECV-01 | Gesture-based UI interaction | 1. Long-press Absensi Enakko logo in header. 2. Verify diagnostics screen opens. 3. Verify it shows pending count, battery, version. |
| Force sync bypasses timer | RECV-02 | Requires network + real Supabase | 1. Insert pending_log. 2. Open diagnostics. 3. Tap Force Sync. 4. Verify count drops to 0 (or error shown). |
| Toast shows sync result | RECV-03 | Visual toast appearance | 1. After force sync, verify success toast shows synced count. 2. When offline, verify offline message. 3. When nothing pending, verify "no pending" message. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
