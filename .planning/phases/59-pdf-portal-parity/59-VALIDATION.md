---
phase: 59
slug: pdf-portal-parity
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-28
---

# Phase 59 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` for the app slice plus `astro check` for the portal slice |
| **Config file** | `analysis_options.yaml` plus `C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/tsconfig.json` |
| **Quick run command** | `powershell -Command "C:\flutter\bin\flutter.bat test test/services/payroll_matrix_semantics_test.dart test/services/pdf_service_color_test.dart test/services/payroll_pdf_matrix_export_service_test.dart test/screens/admin/admin_reports_payroll_matrix_test.dart; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; npm --prefix 'C:\Users\HYPE R Series\Desktop\projekan\absenkok-website' run check"` |
| **Full suite command** | `powershell -Command "C:\flutter\bin\flutter.bat test; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; npm --prefix 'C:\Users\HYPE R Series\Desktop\projekan\absenkok-website' run check"` |
| **Estimated runtime** | ~180 seconds |

---

## Sampling Rate

- **After every task commit:** run the task-local command; changes to matrix semantics or payroll PDF generation should also run `C:\flutter\bin\flutter.bat test test/services/payroll_matrix_semantics_test.dart test/services/payroll_pdf_matrix_export_service_test.dart`
- **After every plan wave:** run the quick run command
- **Before `$gsd-verify-work`:** full suite command must be green
- **Max feedback latency:** 180 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 59-01-01 | 01 | 1 | `SCHED-04` | static/type | `npm --prefix "C:\Users\HYPE R Series\Desktop\projekan\absenkok-website" run check` | ✅ | ⬜ pending |
| 59-01-02 | 01 | 1 | `SCHED-04` | behavior | `npm --prefix "C:\Users\HYPE R Series\Desktop\projekan\absenkok-website" run check` | ❌ behavior W0 | ⬜ pending |
| 59-02-01 | 02 | 2 | `SCHED-04` | behavior / manual | `npm --prefix "C:\Users\HYPE R Series\Desktop\projekan\absenkok-website" run check` | ❌ behavior W0 | ⬜ pending |
| 59-03-01 | 03 | 2 | `REPORT-03` | contract | `C:\flutter\bin\flutter.bat test test/services/payroll_matrix_semantics_test.dart test/services/payroll_pdf_matrix_export_service_test.dart` | ❌ Wave 0 | ⬜ pending |
| 59-04-01 | 04 | 3 | `REPORT-03` | widget | `C:\flutter\bin\flutter.bat test test/screens/admin/admin_reports_payroll_matrix_test.dart` | ✅ partial | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/services/payroll_pdf_matrix_export_service_test.dart` - matrix-driven payroll PDF contract, summary page, legend, and salary-facing field exclusions
- [ ] Extend `test/screens/admin/admin_reports_payroll_matrix_test.dart` - payroll PDF action, loading, success, and error feedback on the recap tab
- [ ] Portal behavior harness in `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website` or an explicit manual-only acceptance checklist for the updated portal schedule and recap cards, anchored to `.planning/phases/59-pdf-portal-parity/59-PARITY-FIXTURES.md`
- [ ] Shared parity fixture for one overnight day and one Phase 58.1 fallback day across spreadsheet, PDF, and portal outputs in `.planning/phases/59-pdf-portal-parity/59-PARITY-FIXTURES.md`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Portal cards read band-first and no longer use exact shift ranges as the primary contract | `SCHED-04` | `astro check` proves types only; it does not prove the employee-facing card hierarchy | Open the portal schedule and recap surfaces on a phone-sized viewport and confirm the main labels are band + required/progress context, with no primary clock-range copy, using the fixture expectations in `.planning/phases/59-pdf-portal-parity/59-PARITY-FIXTURES.md` |
| Current-day portal progress stays calm and understandable for in-progress workdays | `SCHED-04` | The final copy/tone needs a human review on the real card states | Use one in-progress employee day and verify worked/remaining copy reads as provisional rather than punitive while still matching the fixture expectations in `.planning/phases/59-pdf-portal-parity/59-PARITY-FIXTURES.md` |
| Payroll PDF matches spreadsheet cell meaning for the same logical workday | `REPORT-03` | Automated tests can inspect the file contract, but parity is easiest to verify by opening both real exports | Generate one spreadsheet and one PDF for the same outlet/date range, open both, and confirm label, short-tag, and severity-color parity for at least one overnight row and one fallback row from `.planning/phases/59-pdf-portal-parity/59-PARITY-FIXTURES.md` |
| Payroll PDF stays salary-facing and excludes GPS or technical scan fields | `REPORT-03` | The absence of audit fields is clearer in a real viewer than in byte-level assertions alone | Open the generated PDF and confirm there are no latitude, longitude, queue-order, capture-mode, or raw technical provenance columns or notes on the payroll recap pages |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
