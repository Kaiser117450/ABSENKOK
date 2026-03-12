---
phase: 13
slug: soft-archive-karyawan-riwayat
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-11
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) |
| **Config file** | none — default Flutter test runner |
| **Quick run command** | `flutter test test/models/employee_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/models/employee_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | ARCH-01 | unit | `flutter test test/models/employee_test.dart` | ❌ W0 | ⬜ pending |
| 13-01-02 | 01 | 1 | ARCH-05 | unit | `flutter test test/models/employee_test.dart` | ❌ W0 | ⬜ pending |
| 13-02-01 | 02 | 1 | ARCH-04 | widget | `flutter test test/widgets/archive_confirm_dialog_test.dart` | ❌ W0 | ⬜ pending |
| 13-02-02 | 02 | 1 | ARCH-01 | integration | Manual — verify UI flow | N/A | ⬜ pending |
| 13-03-01 | 03 | 2 | ARCH-06 | unit | `flutter test test/screens/admin/archived_employees_test.dart` | ❌ W0 | ⬜ pending |
| 13-03-02 | 03 | 2 | ARCH-05 | unit | `flutter test test/screens/admin/archived_employees_test.dart` | ❌ W0 | ⬜ pending |
| 13-xx-01 | all | all | ARCH-02 | manual | Physical NFC test with archived employee | N/A | ⬜ pending |
| 13-xx-02 | all | all | ARCH-03 | unit | `flutter test test/screens/admin/shift_scheduler_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/models/employee_test.dart` — stubs for ARCH-01, ARCH-05 (archive/restore field updates)
- [ ] `test/screens/admin/archived_employees_test.dart` — stubs for ARCH-06 (Riwayat query logic)
- [ ] `test/widgets/archive_confirm_dialog_test.dart` — stubs for ARCH-04 (confirmation dialog UI)
- [ ] `test/screens/admin/shift_scheduler_test.dart` — stubs for ARCH-03 (schedule filter)

*Framework install: Not needed — flutter_test is SDK package.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| NFC scan rejects archived employee | ARCH-02 | Requires physical NFC card + tablet hardware | 1. Archive test employee 2. Tap NFC card on kiosk 3. Verify "Karyawan tidak aktif" message appears 4. Verify scan NOT recorded in attendance_logs |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
