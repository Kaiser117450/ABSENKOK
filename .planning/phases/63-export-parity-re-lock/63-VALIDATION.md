---
phase: 63
slug: export-parity-re-lock
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-02
---

# Phase 63 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` |
| **Config file** | `analysis_options.yaml` |
| **Quick run command** | `powershell -Command "Remove-Item -LiteralPath build\unit_test_assets -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath build\native_assets -Recurse -Force -ErrorAction SilentlyContinue; C:\flutter\bin\flutter.bat test test/services/report_export_parity_test.dart test/services/payroll_spreadsheet_export_service_test.dart test/services/payroll_pdf_matrix_export_service_test.dart test/screens/admin/admin_reports_payroll_matrix_test.dart test/screens/admin/rekap_harian_test.dart"` |
| **Full suite command** | `powershell -Command "Remove-Item -LiteralPath build\unit_test_assets -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath build\native_assets -Recurse -Force -ErrorAction SilentlyContinue; C:\flutter\bin\flutter.bat test"` |
| **Estimated runtime** | ~180 seconds |

---

## Sampling Rate

- **After every task commit:** run only the task-local command from the map below
- **After every plan wave:** run the quick run command
- **Before `$gsd-verify-work`:** full suite must be green
- **Max feedback latency:** task-local runs should stay under ~90 seconds; reserve ~180-second feedback only for wave or phase gates

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 63-01-01 | 01 | 1 | `REPORT-04`, `REPORT-05` | fixture / contract | `powershell -Command "Remove-Item -LiteralPath build\unit_test_assets -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath build\native_assets -Recurse -Force -ErrorAction SilentlyContinue; C:\flutter\bin\flutter.bat test test/services/report_export_parity_test.dart"` | ❌ Wave 0 / ✅ | ⬜ pending |
| 63-01-02 | 01 | 1 | `REPORT-04`, `REPORT-05` | widget | `powershell -Command "Remove-Item -LiteralPath build\unit_test_assets -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath build\native_assets -Recurse -Force -ErrorAction SilentlyContinue; C:\flutter\bin\flutter.bat test test/screens/admin/admin_reports_payroll_matrix_test.dart"` | ✅ but broken baseline | ⬜ pending |
| 63-02-01 | 02 | 2 | `REPORT-04` | service / workbook contract + colors | `powershell -Command "Remove-Item -LiteralPath build\unit_test_assets -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath build\native_assets -Recurse -Force -ErrorAction SilentlyContinue; C:\flutter\bin\flutter.bat test test/services/payroll_spreadsheet_export_service_test.dart"` | ❌ Wave 0 / ✅ partial | ⬜ pending |
| 63-02-02 | 02 | 2 | `REPORT-05` | service / pdf contract | `powershell -Command "Remove-Item -LiteralPath build\unit_test_assets -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath build\native_assets -Recurse -Force -ErrorAction SilentlyContinue; C:\flutter\bin\flutter.bat test test/services/payroll_pdf_matrix_export_service_test.dart"` | ❌ Wave 0 / ✅ partial | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/fixtures/report_export_parity_fixture.dart` - shared mixed strict/fallback recap inputs and expected admin/export meaning
- [ ] `test/services/report_export_parity_test.dart` - parity contract proving admin recap, spreadsheet export, and payroll PDF stay on the same merged recap dataset
- [ ] Repair or replace `test/screens/admin/admin_reports_payroll_matrix_test.dart` so it targets the current `PolicyRecapTab` composition and reuses a real production payroll-support widget instead of mirrored copy
- [ ] Normalize focused Flutter test commands to pre-clean `build/unit_test_assets` and `build/native_assets` before execution on this Windows workspace

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Spreadsheet and payroll PDF still feel compact and payroll-facing after parity hardening | `REPORT-04`, `REPORT-05` | Automated tests can prove dataset parity and forbidden-field exclusions, but not whether the generated operator artifacts still read as compact payroll evidence | Generate the recap-tab spreadsheet and payroll PDF for a range containing strict, fallback, overtime, and no-schedule rows, then verify the summary columns, compact day-cell text, and overall scanability still match the shipped payroll-facing contract |
| Compatibility-mode output remains understandable when fallback rows are present | `REPORT-05` | Widget and service tests can assert the flag flow, but a human still needs to confirm the generated PDF/export meaning is understandable for payroll review | Export a range that triggers compatibility mode, review the generated spreadsheet and PDF, and confirm fallback-driven rows are communicated without exposing raw scan fields or suggesting a second reporting interpretation |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s for task-local checks
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
