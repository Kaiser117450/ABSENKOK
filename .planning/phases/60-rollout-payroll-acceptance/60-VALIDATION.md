---
phase: 60
slug: rollout-payroll-acceptance
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-31
---

# Phase 60 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` plus targeted PowerShell docs assertions |
| **Config file** | `analysis_options.yaml` |
| **Quick run command** | `powershell -Command "C:\flutter\bin\flutter.bat test test/services/payroll_rollout_acceptance_service_test.dart test/services/payroll_validation_bundle_service_test.dart test/screens/admin/admin_reports_payroll_rollout_test.dart test/screens/admin/admin_reports_payroll_matrix_test.dart"` |
| **Full suite command** | `C:\flutter\bin\flutter.bat test` |
| **Estimated runtime** | ~160 seconds |

---

## Sampling Rate

- **After every task commit:** run the task-local command; docs-only tasks must still run the PowerShell marker check
- **After every plan wave:** run the quick run command
- **Before `$gsd-verify-work`:** full suite command must be green
- **Max feedback latency:** 180 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 60-01-01 | 01 | 1 | `OPS-01` | docs contract | `powershell -Command "Select-String -Path 'docs/payroll-rollout-acceptance.md','.planning/phases/60-rollout-payroll-acceptance/60-USER-SETUP.md','.planning/phases/60-rollout-payroll-acceptance/60-ACCEPTANCE-FIXTURES.md' -Pattern 'Tandai Siap Payroll','Portal','Spreadsheet','PDF','Break-first','No-show' | Measure-Object | Select-Object -ExpandProperty Count"` | ❌ Wave 0 | ⬜ pending |
| 60-02-01 | 02 | 1 | `OPS-01` | unit / contract | `C:\flutter\bin\flutter.bat test test/services/payroll_rollout_acceptance_service_test.dart test/services/payroll_validation_bundle_service_test.dart` | ❌ Wave 0 | ⬜ pending |
| 60-03-01 | 03 | 2 | `OPS-01` | widget | `C:\flutter\bin\flutter.bat test test/screens/admin/admin_reports_payroll_rollout_test.dart test/screens/admin/admin_reports_payroll_matrix_test.dart` | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/services/payroll_rollout_acceptance_service_test.dart` - readiness summary, seven required scenarios, blocked parity rows, and CTA gating
- [ ] `test/services/payroll_validation_bundle_service_test.dart` - exported validation bundle structure and salary-facing field exclusions
- [ ] `test/screens/admin/admin_reports_payroll_rollout_test.dart` - readiness banner, scenario matrix, evidence table, destructive dialog, and action-bar shell
- [ ] `docs/payroll-rollout-acceptance.md` / `60-USER-SETUP.md` / `60-ACCEPTANCE-FIXTURES.md` - locked rollout markers for docs verification

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The same logical workday agrees across admin, spreadsheet, PDF, and portal evidence | `OPS-01` | Widget and unit tests can verify structure, but real export parity still needs a human comparison of generated artifacts | Generate the four artifacts for one required scenario and confirm primary label, short tags, and severity family match exactly |
| The readiness banner and additive-only reminder stay visible before the operator scrolls deep into the recap surface | `OPS-01` | Layout density and first-screen visibility are visual quality checks rather than pure logic | Open the rollout panel on desktop width and confirm `Payroll siap dipakai` / `Payroll belum aman dipakai` plus `Mode rollout additive` are visible above the fold |
| The destructive confirmation dialog appears only for the production-impacting action | `OPS-01` | Automated tests can assert dialog copy, but an end-to-end run is still needed to confirm it does not appear on page load or passive review actions | Open the recap tab, verify no dialog appears initially, then trigger the production-impacting action and confirm the dialog uses the locked warning copy |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
