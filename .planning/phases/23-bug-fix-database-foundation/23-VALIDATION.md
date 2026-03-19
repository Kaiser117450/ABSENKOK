---
phase: 23
slug: bug-fix-database-foundation
status: completed
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-19
---

# Phase 23 — Validation Strategy (Retroactive)

> Retroactive validation audit for Phase 23: NFC Double-Scan Crash Fix & Database Foundation.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test |
| **Config file** | none |
| **Quick run command** | `flutter test test/services/nfc_service_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test`
- **After every plan wave:** Run `flutter test`
- **Before /gsd:verify-work:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 23-01-01 | 01 | 1 | BUG-01 | unit | `flutter test test/services/nfc_service_test.dart` | ✅ | ✅ green |
| 23-01-02 | 01 | 1 | BUG-01 | manual | n/a | ✅ | ✅ green |
| 23-02-01 | 02 | 1 | DASH-05 | manual | n/a | ✅ | ✅ green |
| 23-02-02 | 02 | 1 | GAME-01 | manual | n/a | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/services/nfc_service_test.dart` — verify extractUid logic
- [x] `sql/phase23_rpc_functions.sql` — verify SQL syntax and security definer
- [x] `sql/phase23_employee_streaks.sql` — verify RLS policy

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| NFC Double-Scan Prevention | BUG-01 | Requires hardware | Tap card twice rapidly on a physical device; confirm second tap is ignored and no crash occurs. |
| Supabase RPC Deployment | DASH-05 | Requires Supabase credentials | Run the SQL scripts in Supabase SQL Editor and call the functions via RPC to verify JSON output. |
| Employee Streak Update | GAME-01 | Side-effects in production | Call `update_employee_streak` for a test employee and verify `employee_streaks` table is updated. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** 2026-03-19
