---
phase: 62
slug: schedule-gap-notices
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-01
---

# Phase 62 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` |
| **Config file** | `analysis_options.yaml` |
| **Quick run command** | `C:\flutter\bin\flutter.bat test test/services/schedule_gap_notice_service_test.dart test/screens/admin/admin_dashboard_schedule_gap_test.dart test/services/admin_policy_recap_dataset_service_test.dart` |
| **Full suite command** | `C:\flutter\bin\flutter.bat test` |
| **Estimated runtime** | ~150 seconds |

---

## Sampling Rate

- **After every task commit:** run the task-local command plus the quick run command whenever the notice service or dashboard wiring changed
- **After every plan wave:** run `C:\flutter\bin\flutter.bat test`
- **Before `$gsd-verify-work`:** full suite must be green
- **Max feedback latency:** 150 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 62-01-01 | 01 | 1 | `SCHED-05` | unit | `C:\flutter\bin\flutter.bat test test/services/schedule_gap_notice_service_test.dart` | ❌ Wave 0 | ⬜ pending |
| 62-02-01 | 02 | 2 | `SCHED-05` | widget | `C:\flutter\bin\flutter.bat test test/screens/admin/admin_dashboard_schedule_gap_test.dart` | ❌ Wave 0 | ⬜ pending |
| 62-02-02 | 02 | 2 | `SCHED-05` | regression | `C:\flutter\bin\flutter.bat test test/services/schedule_gap_notice_service_test.dart test/screens/admin/admin_dashboard_schedule_gap_test.dart test/services/admin_policy_recap_dataset_service_test.dart` | ❌ Wave 0 / ❌ Wave 0 / ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/services/schedule_gap_notice_service_test.dart` - pure grouping, outlet scoping, ordering, and non-punitive notice-copy coverage
- [ ] `test/screens/admin/admin_dashboard_schedule_gap_test.dart` - dashboard quick-action badge, detail sheet, outlet scope, and scheduler CTA coverage

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The new notice surface feels lightweight and non-blocking beside existing dashboard quick actions | `SCHED-05` | Widget tests can prove presence and state, but not whether the notice competes too aggressively with the main ops actions on a real tablet | Open the admin dashboard on a tablet-sized layout for both full admin and kepala gerai mode, verify the notice affordance is visible when gaps exist, and confirm it does not dominate or hide the existing quick actions |
| Returning from the scheduler keeps the notice workflow understandable for operators | `SCHED-05` | Navigation timing and operator comprehension are best checked interactively | Trigger the notice CTA, open the scheduler for the scoped outlet, return to the dashboard, refresh, and confirm the notice count and rows update in a way that is obvious to a non-technical operator |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 150s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
