---
phase: 55
slug: schedule-policy-absence-rules
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-26
---

# Phase 55 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (built-in, also used for SQL contract file assertions) |
| **Config file** | `analysis_options.yaml` |
| **Quick run command** | `C:\flutter\bin\flutter.bat test test/models/shift_schedule_test.dart test/screens/admin/rekap_harian_test.dart` |
| **Full suite command** | `C:\flutter\bin\flutter.bat test` |
| **Estimated runtime** | ~90 seconds |

---

## Sampling Rate

- **After every task commit:** Run the targeted file(s) for the touched surface plus `C:\flutter\bin\flutter.bat test test/models/shift_schedule_test.dart test/screens/admin/rekap_harian_test.dart`
- **After every plan wave:** Run `C:\flutter\bin\flutter.bat test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 55-00-01 | 00 | 0 | `SCHED-01` | unit | `C:\flutter\bin\flutter.bat test test/models/schedule_policy_service_test.dart` | ❌ W0 | ⬜ pending |
| 55-00-02 | 00 | 0 | `SCHED-01` | widget | `C:\flutter\bin\flutter.bat test test/screens/admin/schedule_policy_grid_test.dart` | ❌ W0 | ⬜ pending |
| 55-00-03 | 00 | 0 | `SCHED-02` | unit | `C:\flutter\bin\flutter.bat test test/models/schedule_policy_service_test.dart` | ❌ W0 | ⬜ pending |
| 55-00-04 | 00 | 0 | `SCHED-03` | unit | `C:\flutter\bin\flutter.bat test test/phase55/schedule_policy_sql_contract_test.dart` | ❌ W0 | ⬜ pending |
| 55-00-05 | 00 | 0 | `SCHED-03` | widget | `C:\flutter\bin\flutter.bat test test/screens/admin/rekap_harian_test.dart` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/models/schedule_policy_service_test.dart` - canonical band cutoff and break-first window coverage
- [ ] `test/screens/admin/schedule_policy_grid_test.dart` - scheduler cell labels and bulk review summary
- [ ] `test/phase55/schedule_policy_sql_contract_test.dart` - additive SQL contract coverage for recap/read-model changes
- [ ] `test/screens/admin/rekap_harian_test.dart` - extend placeholder specs into executable status-precedence coverage

*Existing infrastructure already covers the baseline `ShiftSlot` serialization path via `test/models/shift_schedule_test.dart`.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Weekly scheduler remains quick-chip and grid-first | `SCHED-01` | Interaction speed and ergonomics are hard to prove from unit tests alone | Open the admin scheduler, assign shifts for one week, and confirm cells stay band-first without introducing a form-heavy workflow |
| Bulk assign review step is lightweight but explicit | `SCHED-01` | Requires interactive confirmation flow review | Select multiple employees, run bulk assign, and confirm the review step shows derived hours before save |
| Manager can distinguish normal late vs break-first late cases | `SCHED-02` | Filtering and label clarity are UI semantics | Open the admin review/report surface and verify late and break-first cases are separately filterable |
| Active-day zero-log schedule is `belum_masuk`, prior-day zero-log schedule is `tidak_hadir` | `SCHED-03` | Logical-day timing depends on live date context | Test one current-day scheduled employee with no scans and one prior-day scheduled employee with no scans; confirm only the prior day resolves to `tidak_hadir` |
| Approved `cuti` does not collapse into `tidak_hadir` | `SCHED-03` | Requires end-to-end exception precedence | Approve a time-off request, load recap/admin views, and confirm the final state stays `cuti` or equivalent approved leave rather than `tidak_hadir` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
