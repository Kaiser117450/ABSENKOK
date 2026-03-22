---
phase: 37
plan: "02"
subsystem: flutter-admin-ui
tags: [employee-portal, provisioning, admin-ui, edge-function]
dependency_graph:
  requires: [37-01]
  provides: [employee-portal-provisioning-ui]
  affects: [lib/screens/admin/admin_employees_screen.dart]
tech_stack:
  added: []
  patterns: [service-layer, typed-result-model, dialog-state-machine]
key_files:
  created:
    - lib/services/employee_portal_provisioning_service.dart
  modified:
    - lib/screens/admin/admin_employees_screen.dart
decisions:
  - "Clipboard copy uses flutter/services.dart Clipboard.setData — no extra package needed"
  - "blockReason check gates archivedAt != null OR isActive == false before form renders"
  - "Dialog state machine: form -> loading -> success/error with retry-to-form path"
metrics:
  duration: "~25 minutes"
  completed: "2026-03-22"
  tasks_completed: 2
  files_modified: 2
---

# Phase 37 Plan 02: Admin Portal Provisioning Flow Summary

One-liner: Flutter service + employee-card dialog provisioning portal credentials via Edge Function with name-search handoff receipt.

## What Was Built

### Task 1: EmployeePortalProvisioningService

`lib/services/employee_portal_provisioning_service.dart` — typed service wrapper for the `provision-employee-portal-user` Edge Function.

- `EmployeePortalProvisionResult` model with `employeeId`, `employeeName`, `authUserId`, `createdAt`
- `provisionAccess(employeeId, password)` method with client-side password guard (min 6 chars)
- Translates non-200 responses to user-facing Indonesian exceptions
- Follows the same pattern as `AdminOnboardingService`

### Task 2: Admin UI Provisioning Entry Point

`lib/screens/admin/admin_employees_screen.dart` — extended with:

- `Buat Akses Portal` menu item in each employee card's `PopupMenuButton`
- `_showProvisionPortalDialog()` in screen state that opens `_ProvisionPortalDialog`
- `_ProvisionPortalDialog`: four-state dialog (form / loading / success / error)
  - **form**: employee context card (name, position, outlet), password + confirm fields, blocks inactive/archived employees with clear reason
  - **loading**: spinner while Edge Function call is in flight
  - **success**: handoff receipt with name, position, outlet, chosen password, copy-to-clipboard action, and instruction `Cari nama Anda di portal, pilih kartu yang cocok, lalu masukkan password ini`
  - **error**: message with Tutup + Coba Lagi (returns to form state)
- `_ReceiptRow` helper widget for the success card layout

## Deviations from Plan

None — plan executed exactly as written. Pre-existing `withOpacity` deprecation warnings in the file are out-of-scope and were not touched.

## Self-Check

### Created files exist:
- `lib/services/employee_portal_provisioning_service.dart` — FOUND
- `_ProvisionPortalDialog` in `lib/screens/admin/admin_employees_screen.dart` — FOUND

### Commits exist:
- `c5f560c` — feat(37-02): create EmployeePortalProvisioningService
- `2a704c1` — feat(37-02): add Buat Akses Portal provisioning flow to employee management UI

## Self-Check: PASSED
