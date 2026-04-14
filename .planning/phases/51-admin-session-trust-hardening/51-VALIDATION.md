---
phase: 51
slug: admin-session-trust-hardening
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-25
---

# Phase 51 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` |
| **Config file** | none - Flutter defaults |
| **Quick run command** | `C:\flutter\bin\flutter.bat test test/phase51/sql_role_guard_contract_test.dart test/phase51/admin_session_claims_test.dart test/screens/admin/admin_login_screen_test.dart test/providers/app_provider_biometric_test.dart` |
| **Full suite command** | `C:\flutter\bin\flutter.bat test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `C:\flutter\bin\flutter.bat test test/phase51/sql_role_guard_contract_test.dart test/phase51/admin_session_claims_test.dart test/screens/admin/admin_login_screen_test.dart test/providers/app_provider_biometric_test.dart`
- **After every plan wave:** Run `C:\flutter\bin\flutter.bat test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 51-01-01 | 01 | 1 | SECACC-01 | contract | `C:\flutter\bin\flutter.bat test test/phase51/sql_role_guard_contract_test.dart` | ❌ W0 | ⬜ pending |
| 51-01-02 | 01 | 1 | SECACC-01 | static / smoke | `Select-String -Path sql/phase_51_admin_session_trust_20260325.sql -Pattern 'get_attendance_rates|get_weekly_trend|get_outlet_comparison|update_employee_streak|get_overtime_flags|get_missing_clockouts|get_arrival_patterns|IS DISTINCT FROM|v_role IS NULL'` | ❌ W0 | ⬜ pending |
| 51-02-01 | 02 | 1 | SECACC-02 | unit | `C:\flutter\bin\flutter.bat test test/phase51/admin_session_claims_test.dart` | ❌ W0 | ⬜ pending |
| 51-02-02 | 02 | 1 | SECACC-03 | unit | `C:\flutter\bin\flutter.bat test test/screens/admin/admin_login_screen_test.dart test/providers/app_provider_biometric_test.dart` | ✅ | ⬜ pending |

*Status: ⬜ pending - ✅ green - ❌ red - ⚠ flaky*

---

## Wave 0 Requirements

- [ ] `sql/phase_51_admin_session_trust_20260325.sql` - additive SQL migration that redefines the vulnerable dashboard/analytics functions
- [ ] `test/phase51/sql_role_guard_contract_test.dart` - migration text contract for fail-closed role guards
- [ ] `lib/core/admin_session_claims.dart` - shared `appMetadata`-only claim resolver
- [ ] `test/phase51/admin_session_claims_test.dart` - valid/invalid claim parsing coverage

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Valid admin biometric re-entry still routes to the dashboard after cold start | SECACC-02, SECACC-03 | Requires a live Supabase session and biometric hardware or emulator prompt | 1. Sign in as admin. 2. Enable biometric login. 3. Restart the app. 4. Approve biometric. 5. Verify `/admin/dashboard` opens without using stored role prefs. |
| Valid `kepala_gerai` biometric re-entry keeps outlet-scoped routing | SECACC-02, SECACC-03 | Requires a scoped account and live Supabase auth | 1. Sign in as `kepala_gerai`. 2. Enable biometric login. 3. Restart the app. 4. Approve biometric. 5. Verify the app opens the outlet-scoped admin surface and still blocks full-admin pages. |
| Invalid or demoted session no longer restores privileged UI after biometric success | SECACC-03 | Requires server-side role mutation or a prepared invalid-claim account | 1. Enable biometric on a privileged account. 2. Remove or invalidate the account's server-side role claim. 3. Restart the app and approve biometric. 4. Verify the login screen remains and no privileged routing occurs. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
