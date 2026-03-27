---
phase: 57
slug: strict-recap-evaluation-engine
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-27
---

# Phase 57 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` plus static SQL contract file assertions |
| **Config file** | `analysis_options.yaml` |
| **Quick run command** | `C:\flutter\bin\flutter.bat test test/phase57/strict_recap_sql_contract_test.dart test/models/attendance_policy_recap_day_test.dart test/services/attendance_policy_recap_service_test.dart test/widgets/attendance_policy_badge_test.dart` |
| **Full suite command** | `C:\flutter\bin\flutter.bat test` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run the task-local automated command; when both SQL and Dart recap contracts changed, also run `C:\flutter\bin\flutter.bat test test/phase57/strict_recap_sql_contract_test.dart test/models/attendance_policy_recap_day_test.dart test/services/attendance_policy_recap_service_test.dart test/widgets/attendance_policy_badge_test.dart`
- **After every plan wave:** Run `C:\flutter\bin\flutter.bat test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 57-01-01 | 01 | 1 | `CONTRACT-03`, `RECAP-01`, `RECAP-02`, `RECAP-03`, `RECAP-04` | static | `powershell -Command "Select-String -Path 'sql/phase_57_strict_recap_evaluation_engine_20260327.sql' -Pattern 'operating_mode','position','primary_status','detail_signals','net_work_minutes','belum_absen_pulang' | Measure-Object | Select-Object -ExpandProperty Count"` | ❌ W0 | ⬜ pending |
| 57-01-02 | 01 | 1 | `CONTRACT-03`, `RECAP-01`, `RECAP-02`, `RECAP-03`, `RECAP-04` | contract | `C:\flutter\bin\flutter.bat test test/phase57/strict_recap_sql_contract_test.dart` | ❌ W0 | ⬜ pending |
| 57-02-01 | 02 | 2 | `CONTRACT-03`, `RECAP-04` | unit | `C:\flutter\bin\flutter.bat test test/models/attendance_policy_recap_day_test.dart` | ❌ W0 | ⬜ pending |
| 57-02-02 | 02 | 2 | `RECAP-01`, `RECAP-02`, `RECAP-03`, `RECAP-04` | unit | `C:\flutter\bin\flutter.bat test test/services/attendance_policy_recap_service_test.dart` | ✅ | ⬜ pending |
| 57-03-01 | 03 | 3 | `RECAP-04` | widget | `C:\flutter\bin\flutter.bat test test/widgets/attendance_policy_badge_test.dart` | ✅ | ⬜ pending |
| 57-03-02 | 03 | 3 | `CONTRACT-03`, `RECAP-04` | widget | `C:\flutter\bin\flutter.bat test test/screens/admin/admin_reports_policy_recap_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/phase57/strict_recap_sql_contract_test.dart` - SQL helper names, strict RPC fields, and logical-day keyword coverage
- [ ] `test/models/attendance_policy_recap_day_test.dart` - typed primary/detail signal parsing and legacy compatibility coverage
- [ ] `test/screens/admin/admin_reports_policy_recap_test.dart` - admin filter, detail-chip, and manager-exemption rendering coverage

*Existing infrastructure already covers the baseline service parse path and badge widget path, but both need Phase 57 expansion.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Overnight 24-hour chain stays on one logical workday | `RECAP-01` | Requires realistic production-like attendance sequences and outlet mode data | Use a `TWENTY_FOUR_HOUR` outlet with `masuk -> break -> kembali -> pulang` crossing midnight, then confirm one recap row appears for the prior logical day |
| Manager exemption remains visible without red penalty | `CONTRACT-03`, `RECAP-04` | Needs real `position` data and operator-facing review | Open a kepala gerai row that is late or short-work and confirm the row stays visible with an exempt marker and non-penal detail notes |
| Current-day incomplete chains stay informational | `RECAP-04` | Depends on "business day still active" timing semantics | Inspect an active logical day with no final `pulang` yet and confirm it does not render as a final red outcome |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
