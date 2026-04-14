---
phase: 53
slug: security-rollout-acceptance
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-03-25
---

# Phase 53 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | PowerShell helper checks, focused `flutter_test`, and Astro `npm run check` / `npm run build` |
| **Config file** | `pubspec.yaml`, `package.json` |
| **Quick run command** | `powershell -ExecutionPolicy Bypass -File tool/security_hardening_acceptance.ps1 -CheckOnly` |
| **Full suite command** | `powershell -ExecutionPolicy Bypass -File tool/security_hardening_acceptance.ps1` |
| **Estimated runtime** | ~180 seconds |

---

## Sampling Rate

- **After every task commit:** run the task-local automated command from the plan
- **After every plan wave:** run `powershell -ExecutionPolicy Bypass -File tool/security_hardening_acceptance.ps1 -CheckOnly`
- **Before `$gsd-verify-work`:** run `powershell -ExecutionPolicy Bypass -File tool/security_hardening_acceptance.ps1`
- **Max feedback latency:** 180 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 53-01-01 | 01 | 1 | SECOPS-01 | source smoke | `powershell -Command "Select-String -Path 'docs/security-hardening-rollout.md' -Pattern 'phase_50_kiosk_boundary_hardening_20260325.sql','phase_51_admin_session_trust_20260325.sql','phase_52_portal_search_minimization_20260325.sql','repair_employee_portal_accounts_20260325.sql','npm run check','npm run build','android-release-runbook.md' | Measure-Object"` | ❌ W0 | ⬜ pending |
| 53-01-02 | 01 | 1 | SECOPS-01 | source smoke | `powershell -Command "Select-String -Path '.planning/phases/53-security-rollout-acceptance/53-USER-SETUP.md' -Pattern 'Status: Incomplete','tmapxdftdhxovthgbhww','repair_employee_portal_accounts_20260325.sql','SQL Editor','passwordless' | Measure-Object"` | ❌ W0 | ⬜ pending |
| 53-02-01 | 02 | 1 | SECOPS-01 | helper check | `powershell -ExecutionPolicy Bypass -File tool/security_hardening_acceptance.ps1 -CheckOnly` | ❌ W0 | ⬜ pending |
| 53-02-02 | 02 | 1 | SECOPS-01 | contract | `C:\flutter\bin\flutter.bat test test/phase53/security_hardening_acceptance_contract_test.dart` | ❌ W0 | ⬜ pending |
| 53-03-01 | 03 | 2 | SECOPS-01 | source smoke | `powershell -Command "Select-String -Path '.planning/phases/53-security-rollout-acceptance/53-ACCEPTANCE.md' -Pattern 'status: pending','Fixed findings','Accepted findings','Open blockers','security_hardening_acceptance.ps1','repair_employee_portal_accounts_20260325.sql' | Measure-Object"` | ❌ W0 | ⬜ pending |
| 53-03-02 | 03 | 2 | SECOPS-01 | source smoke | `powershell -Command "Select-String -Path '.planning/phases/53-security-rollout-acceptance/53-RISK-REGISTER.md' -Pattern 'Accepted risks','passwordless employee portal sign-in','local-only portal logout','Follow-up work / PRs','None yet','repair_employee_portal_accounts_20260325.sql' | Measure-Object"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending - ✅ green - ❌ red - ⚠ flaky*

---

## Wave 0 Requirements

None - existing PowerShell, Flutter, and Astro infrastructure covers the planned automation once the Phase 53 helper and contract test files land during execution.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The live Supabase project receives the Phase 50, 51, and 52 SQL in order, and the recovery script stays conditional | SECOPS-01 | The production database rollout requires explicit human approval and dashboard confirmation | In the approved rollout window, apply the three additive SQL files in order inside project `tmapxdftdhxovthgbhww`, record confirmation for each, and only run `sql/repair_employee_portal_accounts_20260325.sql` if a real recovery scenario exists. |
| The hardened Flutter surfaces still behave correctly after rollout: admin login remains scoped, kiosk device boundaries remain intact, and device management still works | SECOPS-01 | Live surface confidence needs a real operator/device pass, not just repo-local tests | On a current hardened Android build, verify admin login succeeds for valid roles, verify invalid role trust is rejected, and smoke the kiosk activation / heartbeat / device-management surfaces against the rolled-out backend. |
| The hardened portal boundary still behaves as intended after rollout while keeping the accepted passwordless flow | SECOPS-01 | Browser-visible redirect, chooser behavior, and accepted-risk framing require real SSR/browser observation | In a clean browser session, confirm protected `/portal` routes redirect before content renders, the public chooser still works with the tightened search boundary, and any accepted passwordless behavior is recorded as accepted rather than as a failed fix. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or existing infrastructure coverage
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
