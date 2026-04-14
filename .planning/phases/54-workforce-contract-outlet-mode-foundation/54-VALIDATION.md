---
phase: 54
slug: workforce-contract-outlet-mode-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-26
---

# Phase 54 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` plus targeted PowerShell SQL/source smoke checks |
| **Config file** | `pubspec.yaml` |
| **Quick run command** | `C:\flutter\bin\flutter.bat test test/models/workforce_metadata_test.dart test/services/csv_import_service_test.dart test/widgets/employee_contract_badge_test.dart test/widgets/outlet_mode_badge_test.dart` |
| **Full suite command** | `C:\flutter\bin\flutter.bat test` |
| **Estimated runtime** | ~45 seconds |

---

## Sampling Rate

- **After every task commit:** run the task-local automated command from the plan
- **After every plan wave:** run `C:\flutter\bin\flutter.bat test test/models/workforce_metadata_test.dart test/services/csv_import_service_test.dart test/widgets/employee_contract_badge_test.dart test/widgets/outlet_mode_badge_test.dart`
- **Before `$gsd-verify-work`:** run `C:\flutter\bin\flutter.bat test`
- **Max feedback latency:** 45 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 54-01-01 | 01 | 1 | CONTRACT-01, CONTRACT-02 | unit | `C:\flutter\bin\flutter.bat test test/models/workforce_metadata_test.dart` | ❌ W0 | ⬜ pending |
| 54-01-02 | 01 | 1 | CONTRACT-01, CONTRACT-02 | static | `powershell -Command "Select-String -Path 'sql/phase_54_workforce_contract_outlet_mode_20260326.sql' -Pattern 'CREATE TYPE public.employee_contract','CREATE TYPE public.outlet_operating_mode','ALTER TABLE public.employees','ALTER TABLE public.outlets','SET NOT NULL' | Measure-Object | Select-Object -ExpandProperty Count"` | ❌ W0 | ⬜ pending |
| 54-02-01 | 02 | 2 | CONTRACT-01 | widget | `C:\flutter\bin\flutter.bat test test/widgets/employee_contract_badge_test.dart` | ❌ W0 | ⬜ pending |
| 54-02-02 | 02 | 2 | CONTRACT-01 | static | `C:\flutter\bin\flutter.bat analyze lib/screens/admin/admin_employees_screen.dart lib/widgets/employee_contract_badge.dart` | ✅ | ⬜ pending |
| 54-02-03 | 02 | 2 | CONTRACT-01 | static | `C:\flutter\bin\flutter.bat analyze lib/screens/admin/archived_employees_screen.dart lib/widgets/employee_contract_badge.dart` | ✅ | ⬜ pending |
| 54-03-01 | 03 | 2 | CONTRACT-01 | unit | `C:\flutter\bin\flutter.bat test test/services/csv_import_service_test.dart` | ✅ | ⬜ pending |
| 54-03-02 | 03 | 2 | CONTRACT-01 | static | `C:\flutter\bin\flutter.bat analyze lib/screens/admin/csv_import_screen.dart` | ✅ | ⬜ pending |
| 54-04-01 | 04 | 2 | CONTRACT-02 | widget | `C:\flutter\bin\flutter.bat test test/widgets/outlet_mode_badge_test.dart` | ❌ W0 | ⬜ pending |
| 54-04-02 | 04 | 2 | CONTRACT-02 | static | `C:\flutter\bin\flutter.bat analyze lib/screens/admin/admin_outlets_screen.dart lib/widgets/outlet_mode_badge.dart` | ✅ | ⬜ pending |

*Status: ⬜ pending - ✅ green - ❌ red - ⚠ flaky*

---

## Wave 0 Requirements

- [ ] `test/models/workforce_metadata_test.dart` - typed employee/outlet metadata parse and round-trip coverage
- [ ] `test/widgets/employee_contract_badge_test.dart` - contract badge rendering coverage
- [ ] `test/widgets/outlet_mode_badge_test.dart` - outlet mode badge rendering coverage

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Production database receives the additive Phase 54 migration only after explicit user approval | CONTRACT-01, CONTRACT-02 | The repo rules require human approval before any live database change | After approving the rollout window, run `sql/phase_54_workforce_contract_outlet_mode_20260326.sql` in Supabase SQL Editor, confirm the new columns and defaults exist, and record that the migration was additive-only. |
| Admin operators can visually audit contract and outlet-mode badges on the real app surfaces without layout regressions | CONTRACT-01, CONTRACT-02 | Badge density, segmented-control ergonomics, and archive/list readability are best confirmed in the actual admin UI | Open the employee list, archived employee list, CSV import preview, and outlet list; verify the new badges and segmented controls remain readable on the target device size. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or existing infrastructure coverage
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 45s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
