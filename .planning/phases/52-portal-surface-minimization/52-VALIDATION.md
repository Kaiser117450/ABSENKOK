---
phase: 52
slug: portal-surface-minimization
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-25
---

# Phase 52 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Astro `npm run check` / `npm run build`, PowerShell source checks, focused `flutter_test` contract coverage |
| **Config file** | none beyond existing repo defaults |
| **Quick run command** | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` |
| **Full suite command** | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` plus `C:\flutter\bin\flutter.bat test test/phase52/portal_recovery_contract_test.dart` |
| **Estimated runtime** | ~45 seconds |

---

## Sampling Rate

- **After every task commit:** run the smallest relevant command (`npm run check`, source smoke, or the focused Phase 52 Flutter contract test)
- **After every plan wave:** run `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` plus `C:\flutter\bin\flutter.bat test test/phase52/portal_recovery_contract_test.dart`
- **Before `$gsd-verify-work`:** website build and the Phase 52 contract test must be green
- **Max feedback latency:** 45 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 52-01-01 | 01 | 1 | SECPORT-01 | source / build smoke | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` | Existing | ⬜ pending |
| 52-01-02 | 01 | 1 | SECPORT-01 | source smoke | `powershell -Command "Select-String -Path 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/middleware.ts','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/employee.ts' -Pattern 'isProtectedPortalRoute','return redirect','portalUser','cachedUser' | Measure-Object"` | Existing | ⬜ pending |
| 52-02-01 | 02 | 1 | SECPORT-02 | source smoke | `powershell -Command "Select-String -Path 'sql/phase_52_portal_search_minimization_20260325.sql','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/auth.ts','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/auth/search.ts','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/login.astro' -Pattern 'SEARCH_MIN_LENGTH','SEARCH_MAX_RESULTS','SEARCH_MAX_QUERY_LENGTH','employee_name','home_outlet_name','photo_url' | Measure-Object"` | ❌ W0 | ⬜ pending |
| 52-02-02 | 02 | 1 | SECPORT-02 | check / build | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` | Existing | ⬜ pending |
| 52-03-01 | 03 | 1 | SECPORT-03 | contract | `C:\flutter\bin\flutter.bat test test/phase52/portal_recovery_contract_test.dart` | ❌ W0 | ⬜ pending |
| 52-03-02 | 03 | 1 | SECPORT-03 | source smoke | `powershell -Command "Select-String -Path 'sql/repair_employee_portal_accounts_20260325.sql','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/provision.ts','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/auth/sign-in.ts' -Pattern 'employee_portal','employee_id','email_confirmed_at','ON CONFLICT','invalid' | Measure-Object"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending - ✅ green - ❌ red - ⚠ flaky*

---

## Wave 0 Requirements

- [ ] `sql/phase_52_portal_search_minimization_20260325.sql` - additive public-search hardening patch
- [ ] `sql/repair_employee_portal_accounts_20260325.sql` - fail-closed portal-account recovery script
- [ ] `test/phase52/portal_recovery_contract_test.dart` - focused contract test for the new recovery script

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Unauthenticated requests to `/portal` and `/portal/attendance` redirect immediately to `/portal/login` without protected shell content flashing first | SECPORT-01 | Needs a real browser request/redirect lifecycle | Open a clean browser with no Supabase cookies, request `/portal`, then `/portal/attendance`, and confirm both land on `/portal/login` before protected page content appears. |
| The tighter chooser contract still lets a valid employee find their card and enter the passwordless portal flow | SECPORT-02 | Needs live typing, debounce, and endpoint behavior | On `/portal/login`, type a valid name using the new minimum threshold, confirm the chooser appears with the reduced card payload, select the correct card, and verify the form auto-submits successfully. |
| The hardened recovery script restores only confirmed employee-portal identities with matching bindings and skips conflicts for manual review | SECPORT-03 | Requires a prepared database recovery scenario | In a safe environment, create one valid recoverable employee-portal user and one conflicting hidden-email user, run the new repair script, and confirm only the valid case is restored while the conflict remains untouched. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 45s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
