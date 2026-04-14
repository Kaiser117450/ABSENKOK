---
phase: 61
slug: recap-semantics-recovery
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-01
---

# Phase 61 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` |
| **Config file** | `analysis_options.yaml` |
| **Quick run command** | `C:\flutter\bin\flutter.bat test test/services/admin_policy_recap_dataset_service_test.dart test/screens/admin/admin_reports_policy_recap_test.dart test/screens/admin/rekap_harian_test.dart test/services/attendance_policy_recap_service_test.dart test/services/legacy_payroll_recap_fallback_service_test.dart` |
| **Full suite command** | `C:\flutter\bin\flutter.bat test` |
| **Estimated runtime** | ~150 seconds |

---

## Sampling Rate

- **After every task commit:** run the task-local command plus the quick run command whenever the merged recap service or recap tab wiring changed
- **After every plan wave:** run `C:\flutter\bin\flutter.bat test`
- **Before `$gsd-verify-work`:** full suite must be green
- **Max feedback latency:** 150 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 61-01-01 | 01 | 1 | `RECAP-05`, `RECAP-06`, `RECAP-07` | unit | `C:\flutter\bin\flutter.bat test test/services/admin_policy_recap_dataset_service_test.dart` | ❌ Wave 0 | ⬜ pending |
| 61-02-01 | 02 | 2 | `RECAP-05`, `RECAP-06` | widget / helper | `C:\flutter\bin\flutter.bat test test/screens/admin/admin_reports_policy_recap_test.dart test/screens/admin/rekap_harian_test.dart` | ✅ partial / ❌ placeholder | ⬜ pending |
| 61-02-02 | 02 | 2 | `RECAP-05`, `RECAP-06`, `RECAP-07` | contract / regression | `C:\flutter\bin\flutter.bat test test/services/admin_policy_recap_dataset_service_test.dart test/screens/admin/admin_reports_policy_recap_test.dart test/screens/admin/rekap_harian_test.dart` | ❌ Wave 0 / ✅ partial / ❌ placeholder | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/services/admin_policy_recap_dataset_service_test.dart` - pure merged strict-plus-fallback recap dataset coverage, including strict-wins and overnight-safe logical-day cases
- [ ] Replace placeholder `test/screens/admin/rekap_harian_test.dart` with real widget coverage for row visibility, compatibility disclosure, and pending semantics
- [ ] Extend `test/screens/admin/admin_reports_policy_recap_test.dart` with mixed strict-plus-fallback filter behavior on the active recap surface

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Rekap Harian remains usable on a narrow admin device layout when compatibility rows, filter chips, and pending counts are all visible | `RECAP-05` | Widget tests can prove state, but not the practical scanability of the full desktop-to-mobile recap layout | Open the admin reports screen on a phone-sized or narrow tablet viewport, load an outlet/date range with mixed strict and fallback rows, and confirm operators can still scan the compatibility note, pending filters, and day rows without layout breakage |
| Mixed strict-plus-fallback day rows read truthfully to operators | `RECAP-06`, `RECAP-07` | Human review is needed to confirm the reason copy and status hierarchy stay calm and accurate in real data | Load one strict overnight row and one fallback no-schedule row, then confirm the strict row still shows its richer signal while the fallback row explicitly reads as no-schedule compatibility without late or absence penalties |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 150s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
