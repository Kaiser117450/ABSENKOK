---
phase: 50
slug: kiosk-device-boundary-hardening
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-25
---

# Phase 50 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` + PowerShell structural checks |
| **Config file** | none — uses Flutter defaults |
| **Quick run command** | `C:\flutter\bin\flutter.bat test test/phase50/kiosk_device_model_test.dart` |
| **Full suite command** | `C:\flutter\bin\flutter.bat test` |
| **Estimated runtime** | ~30 seconds for the focused phase tests |

---

## Sampling Rate

- **After every task commit:** Run the task's `<automated>` command plus the quick run command if Dart files changed.
- **After every plan wave:** Run `C:\flutter\bin\flutter.bat test`
- **Before `$gsd-verify-work`:** Full suite must be green and the Phase 50 SQL migration must be reviewed for additive-only behavior.
- **Max feedback latency:** 30 seconds for Dart regressions, under 10 seconds for SQL structural checks.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 50-01-01 | 01 | 1 | SECDEV-01 | structural SQL | `Select-String -Path sql/phase_50_kiosk_boundary_hardening_20260325.sql -Pattern 'activate_kiosk_device|upsert_kiosk_heartbeat|GRANT EXECUTE ON FUNCTION public.activate_kiosk_device|GRANT EXECUTE ON FUNCTION public.upsert_kiosk_heartbeat'` | ❌ W0 | ⬜ pending |
| 50-01-01 | 01 | 1 | SECDEV-02 | structural SQL | `Select-String -Path sql/phase_50_kiosk_boundary_hardening_20260325.sql -Pattern 'set_device_nickname|archive_device|auth.jwt\\(|managed_outlet_id|REVOKE ALL ON FUNCTION public.set_device_nickname|REVOKE ALL ON FUNCTION public.archive_device'` | ❌ W0 | ⬜ pending |
| 50-01-02 | 01 | 1 | SECDEV-01 | analyze | `C:\flutter\bin\flutter.bat analyze lib/screens/setup/setup_screen.dart` | ✅ | ⬜ pending |
| 50-02-01 | 02 | 1 | SECSAFE-01 | unit | `C:\flutter\bin\flutter.bat test test/phase50/kiosk_device_model_test.dart` | ❌ W0 | ⬜ pending |
| 50-02-02 | 02 | 1 | SECSAFE-01 | analyze | `C:\flutter\bin\flutter.bat analyze lib/models/kiosk_device.dart lib/screens/admin/admin_dashboard_screen.dart` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `sql/phase_50_kiosk_boundary_hardening_20260325.sql` — additive migration for activation-bound heartbeat and scoped rename/archive RPCs.
- [ ] `test/phase50/kiosk_device_model_test.dart` — regression cases for short, empty, null, and malformed device UUID data.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Apply the additive Phase 50 SQL migration to the live Supabase project and confirm one kiosk can still activate cleanly | SECDEV-01, SECDEV-02 | Production database changes require explicit user approval and a real project connection | Review the SQL, get user confirmation, run it in Supabase SQL Editor, then re-run the existing kiosk activation flow on a safe outlet before broader rollout. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify commands
- [ ] Sampling continuity is maintained across both Phase 50 plans
- [ ] Wave 0 covers the missing SQL migration and the new phase test file
- [ ] No watch-mode flags are used
- [ ] Feedback latency stays under 30 seconds for the focused Dart regression loop
- [ ] `nyquist_compliant: true` is set in frontmatter before phase closeout

**Approval:** pending
