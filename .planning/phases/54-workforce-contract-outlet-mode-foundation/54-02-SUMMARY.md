---
phase: 54-workforce-contract-outlet-mode-foundation
plan: 02
subsystem: admin-employees
tags: [employee, contract, archive, admin-ui]
dependency_graph:
  requires: [EmployeeContract, employment_contract_column]
  provides: [employee_contract_badge, employee_contract_filter, employee_contract_sheet]
  affects: [admin_employees_screen, archived_employees_screen]
tech_stack:
  added: []
  patterns: [shared-badge-widget, typed-enum-form-state, additive-admin-filter]
key_files:
  created:
    - lib/widgets/employee_contract_badge.dart
    - test/widgets/employee_contract_badge_test.dart
  modified:
    - lib/screens/admin/admin_employees_screen.dart
    - lib/screens/admin/archived_employees_screen.dart
decisions:
  - New employee sheets default contract selection to PARTTIME while edit sheets preserve the stored value
  - Contract chips compose with the existing outlet filter instead of replacing it
  - Archived employees reuse the same badge widget as the active list for audit consistency
requirements-completed: [CONTRACT-01]
metrics:
  completed: 2026-03-27
  tasks: 3
---

# Phase 54 Plan 02: Employee Contract Surfaces Summary

Active and archived employee flows now render one shared contract badge, support contract filtering, and always persist a typed contract value through the employee sheet.

## What Was Verified

1. `EmployeeContractBadge` renders readable `Full-Time` and `Part-Time` labels from the typed enum.
2. `AdminEmployeesScreen` composes contract filtering with the existing outlet and search filters.
3. The employee sheet defaults new employees to `PARTTIME`, preserves stored values on edit, and includes `employment_contract` in save payloads.
4. `ArchivedEmployeesScreen` shows the stored contract beside archived employee metadata without changing restore behavior.

## Key Files

- `lib/widgets/employee_contract_badge.dart`
- `test/widgets/employee_contract_badge_test.dart`
- `lib/screens/admin/admin_employees_screen.dart`
- `lib/screens/admin/archived_employees_screen.dart`

## Verification

- `C:\flutter\bin\flutter.bat test test/widgets/employee_contract_badge_test.dart`
- `C:\flutter\bin\flutter.bat analyze lib/screens/admin/admin_employees_screen.dart lib/widgets/employee_contract_badge.dart`
- `C:\flutter\bin\flutter.bat analyze lib/screens/admin/archived_employees_screen.dart lib/widgets/employee_contract_badge.dart`
