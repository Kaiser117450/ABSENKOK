---
phase: 54-workforce-contract-outlet-mode-foundation
plan: 03
subsystem: csv-import
tags: [csv, employee, contract, onboarding]
dependency_graph:
  requires: [EmployeeContract, employment_contract_column]
  provides: [contract_aware_csv_schema, csv_contract_validation, csv_contract_preview]
  affects: [csv_import_result, csv_import_service, csv_import_screen]
tech_stack:
  added: []
  patterns: [pure-service-validation, typed-contract-normalization, operator-preview]
key_files:
  created: []
  modified:
    - lib/models/csv_import_result.dart
    - lib/services/csv_import_service.dart
    - lib/screens/admin/csv_import_screen.dart
    - test/models/csv_import_result_test.dart
    - test/services/csv_import_service_test.dart
decisions:
  - CSV rows now carry the raw contract cell and a separately resolved typed contract for validation and preview
  - Contract validation uses `EmployeeContract.tryParse(...)` so invalid values surface as operator errors instead of silently defaulting
  - Preview shows normalized labels for valid rows and raw contract text for invalid rows
requirements-completed: [CONTRACT-01]
metrics:
  completed: 2026-03-27
  tasks: 2
---

# Phase 54 Plan 03: Contract-Aware CSV Import Summary

The CSV onboarding flow now requires a `kontrak` column, normalizes supported aliases into canonical contract values, persists `employment_contract`, and exposes the contract requirement clearly in the admin wizard.

## What Was Built

1. `CsvRow` and `CsvRowValidation` now carry raw contract input plus a resolved typed contract.
2. `CsvImportService` moved from a 4-column schema to `nama,jabatan,gerai,kontrak,foto_url`.
3. CSV validation rejects legacy templates without `kontrak`, normalizes aliases like `PARTIME` / `part-time`, and emits canonical `employment_contract` payloads.
4. `CsvImportScreen` now advertises the required contract column and shows a dedicated `Kontrak` preview column.
5. Model and service tests now cover the expanded contract-aware schema.

## Key Files

- `lib/models/csv_import_result.dart`
- `lib/services/csv_import_service.dart`
- `lib/screens/admin/csv_import_screen.dart`
- `test/models/csv_import_result_test.dart`
- `test/services/csv_import_service_test.dart`

## Verification

- `C:\flutter\bin\flutter.bat test test/models/csv_import_result_test.dart test/services/csv_import_service_test.dart test/widgets/employee_contract_badge_test.dart test/widgets/outlet_mode_badge_test.dart`
- `C:\flutter\bin\dart.bat analyze lib/models/csv_import_result.dart lib/services/csv_import_service.dart lib/screens/admin/csv_import_screen.dart`
