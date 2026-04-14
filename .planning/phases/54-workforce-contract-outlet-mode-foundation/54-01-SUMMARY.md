---
phase: 54-workforce-contract-outlet-mode-foundation
plan: 01
subsystem: models, database
tags: [enum, employee, outlet, migration, workforce]
dependency_graph:
  requires: []
  provides: [EmployeeContract, OutletOperatingMode, employment_contract_column, operating_mode_column]
  affects: [employee.dart, outlet.dart, attendance_log.dart]
tech_stack:
  added: []
  patterns: [typed-enum-with-parse-helper, safe-null-fallback, additive-migration]
key_files:
  created:
    - lib/models/employee_contract.dart
    - lib/models/outlet_operating_mode.dart
    - sql/phase_54_workforce_contract_outlet_mode_20260326.sql
    - test/models/workforce_metadata_test.dart
  modified:
    - lib/models/employee.dart
    - lib/models/outlet.dart
decisions:
  - EmployeeContract.parse strips hyphens then uppercases for alias normalization
  - Outlet model does not need copyWith (no admin edit surface yet)
  - SQL uses DO/EXCEPTION block for CREATE TYPE idempotency (Postgres has no CREATE TYPE IF NOT EXISTS)
requirements-completed: [CONTRACT-01, CONTRACT-02]
metrics:
  duration: 197s
  completed: 2026-03-26
  tasks: 2
  files: 6
---

# Phase 54 Plan 01: Workforce Contract & Outlet Mode Foundation Summary

Typed enum helpers for employee contract and outlet operating mode, with extended models and additive SQL migration.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Typed workforce metadata enums + model extensions | 418cbc4 | employee_contract.dart, outlet_operating_mode.dart, employee.dart, outlet.dart, workforce_metadata_test.dart |
| 2 | Additive SQL migration | 2bc20d6 | phase_54_workforce_contract_outlet_mode_20260326.sql |

## What Was Built

1. **EmployeeContract enum** -- FULLTIME/PARTTIME with dbValue, label, parse helper that normalizes aliases (PARTIME, part-time, full-time, mixed case). Null/unknown falls back to FULLTIME.

2. **OutletOperatingMode enum** -- NORMAL/TWENTY_FOUR_HOUR with dbValue, label ("Normal"/"24 Jam"), parse helper. Null/unknown falls back to NORMAL.

3. **Employee model extended** -- `employmentContract` field parsed from `employment_contract` in fromJson, emitted in toJson, available in copyWith. Default is FULLTIME so existing code without the DB column still works.

4. **Outlet model extended** -- `operatingMode` field parsed from `operating_mode` in fromJson, emitted in toJson. Default is NORMAL.

5. **29 regression tests** covering enum parsing, alias normalization, null fallback, Employee/Outlet fromJson/toJson round-trips, copyWith, and existing field preservation.

6. **Additive SQL migration** -- CREATE TYPE for both enums (idempotent), ADD COLUMN IF NOT EXISTS with defaults, backfill nulls, then SET NOT NULL. No destructive changes.

## Decisions Made

- `EmployeeContract.parse` strips hyphens before uppercasing, so "part-time" -> "PARTTIME" and "PARTIME" (typo) both resolve correctly.
- SQL uses `DO $$ BEGIN CREATE TYPE ... EXCEPTION WHEN duplicate_object THEN NULL; END $$` because PostgreSQL has no `CREATE TYPE IF NOT EXISTS`.
- Outlet model does not add copyWith since no admin outlet edit surface exists yet (deferred to later plans).

## Deviations from Plan

None -- plan executed exactly as written.

## Verification Results

- `flutter test test/models/workforce_metadata_test.dart` -- 29/29 passed
- SQL file contains all required patterns (CREATE TYPE, ALTER TABLE, SET NOT NULL) -- 8 matches confirmed
