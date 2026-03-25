---
phase: 53-security-rollout-acceptance
plan: closeout
status: pending
created: 2026-03-25
---

# Phase 53 — Security Rollout Acceptance Packet

This packet records rollout evidence and closeout status for the Phase 50-52 security hardening milestone (v7.1). It separates what was fixed, what remains intentionally accepted, and what evidence is still pending from the live rollout window.

**Canonical rollout checklist:** `docs/security-hardening-rollout.md`
**Acceptance helper command surface:** `tool/security_hardening_acceptance.ps1`
**Retained-risk ledger:** `.planning/phases/53-security-rollout-acceptance/53-RISK-REGISTER.md`

---

## 1. Rollout Confirmation

Apply migrations in the exact order below using the Supabase SQL Editor (project `tmapxdftdhxovthgbhww`). Record outcome after each step.

| Step | File | Surface | Status | Notes |
|------|------|---------|--------|-------|
| Phase 50 SQL | `sql/phase_50_kiosk_boundary_hardening_20260325.sql` | Supabase | PENDING | Not yet applied to production |
| Phase 51 SQL | `sql/phase_51_admin_session_trust_20260325.sql` | Supabase | PENDING | Not yet applied to production |
| Phase 52 SQL | `sql/phase_52_portal_search_minimization_20260325.sql` | Supabase | PENDING | Not yet applied to production |
| Recovery script | `sql/repair_employee_portal_accounts_20260325.sql` | Supabase | CONDITIONAL — do NOT apply unless Appendix A conditions are met | |

The recovery script is NOT part of the routine rollout path. See Appendix A of `docs/security-hardening-rollout.md` for conditions.

---

## 2. Verification Matrix

### 2a. Kiosk / Device Hardening

| Check | Expected | Result | Evidence |
|-------|----------|--------|---------|
| Phase 50 SQL applied in Supabase | No errors; `activate_kiosk_device` function exists | PENDING | |
| Flutter kiosk model regression | `test/phase50/kiosk_device_model_test.dart` green | PENDING | |
| Kiosk UUID parsing degrades safely on malformed input | No crash; fallback to null/displayName prefix | PENDING | Structural: covered by test file |

### 2b. Admin Session Trust

| Check | Expected | Result | Evidence |
|-------|----------|--------|---------|
| Phase 51 SQL applied in Supabase | No errors; analytics RPCs read role from `app_metadata` | PENDING | |
| Flutter admin session claims regression | `test/phase51/admin_session_claims_test.dart` green | PENDING | |
| Flutter SQL role guard contract | `test/phase51/sql_role_guard_contract_test.dart` green | PENDING | |
| Null-role JWT rejected by analytics RPCs | Caller without valid `app_metadata` role cannot reach outlet data | PENDING | Structural: role guard in SQL migration |

### 2c. Portal Search / Middleware / Recovery

| Check | Expected | Result | Evidence |
|-------|----------|--------|---------|
| Phase 52 SQL applied in Supabase | No errors; `search_portal_employees` returns narrowed DTO | PENDING | |
| Flutter portal recovery contract | `test/phase52/portal_recovery_contract_test.dart` green | PENDING | See open blocker below |
| Astro portal check | `npm run check` — zero errors | PENDING | |
| Astro portal build | `npm run build` — no build failures | PENDING | |
| Middleware redirects before `next()` | Protected `/portal` routes redirect unauthenticated callers before downstream handlers run | PENDING | Structural: shipped in Phase 52 |
| Chooser search minimum 3 chars | Inputs under 3 characters return no results | PENDING | Structural: Phase 52 SQL + Astro endpoint |
| Chooser result cap | At most 5 results returned | PENDING | Structural: Phase 52 SQL |

### 2d. Acceptance Helper Command Surface

The helper `tool/security_hardening_acceptance.ps1` provides the repo-local Flutter and Astro verification surface.

Run to verify command surface (read-only):
```powershell
powershell -ExecutionPolicy Bypass -File tool/security_hardening_acceptance.ps1 -CheckOnly
```

Run to execute all acceptance checks:
```powershell
powershell -ExecutionPolicy Bypass -File tool/security_hardening_acceptance.ps1
```

**Important:** This helper does NOT execute SQL or apply the recovery script. Live Supabase rollout (Sections 2a-2c SQL steps) remains manual evidence captured by the operator.

| Helper check | Command | Status |
|-------------|---------|--------|
| Phase 50 kiosk device model regression | `flutter test test/phase50/kiosk_device_model_test.dart` | PENDING |
| Phase 51 admin session claims regression | `flutter test test/phase51/admin_session_claims_test.dart` | PENDING |
| Phase 51 SQL role guard contract | `flutter test test/phase51/sql_role_guard_contract_test.dart` | PENDING |
| Phase 52 portal recovery contract | `flutter test test/phase52/portal_recovery_contract_test.dart` | PENDING |
| Astro check | `npm run check` (website project root) | PENDING |
| Astro build | `npm run build` (website project root) | PENDING |

---

## 3. Fixed Findings

These issues were identified and remediated in Phases 50-52. They are NOT open issues.

| # | Finding | Remediation | Phase | Surface |
|---|---------|-------------|-------|---------|
| F-01 | Kiosk device could be activated/heartbeat-written without a confirmed UUID binding | `activate_kiosk_device` RPC now enforces UUID binding; `upsert_kiosk_heartbeat` only refreshes an existing active binding | 50 | Supabase SQL |
| F-02 | `set_device_nickname` and `archive_device` had no role gate | Both RPCs now require authenticated `admin` or correctly-scoped `kepala_gerai` callers | 50 | Supabase SQL |
| F-03 | Kiosk model parsing could crash on malformed UUID or timestamp payloads | `KioskDevice.fromJson` now degrades safely with null fallbacks | 50 | Flutter |
| F-04 | Admin session trust relied on writable `user_metadata` | Analytics RPCs now read role from server-issued `app_metadata`; null-role callers are rejected | 51 | Supabase SQL + Flutter |
| F-05 | Portal public chooser exposed a non-minimal employee DTO with no input cap | `search_portal_employees` now returns only a display-name DTO, caps at 5 results, requires ≥3 normalized characters, and rejects inputs over 64 characters | 52 | Supabase SQL |
| F-06 | Portal route middleware ran `next()` before auth was verified | Middleware now redirects unauthenticated requests before calling `next()`; `resolvePortalEmployee()` trusts the cached middleware boundary | 52 | Astro portal |
| F-07 | Portal account recovery (`repair_employee_portal_accounts`) could repoint `auth_user_id` to an unconfirmed account | Recovery script now fails closed: it skips rows with conflicting `employee_portal` metadata instead of repointing ownership | 52 | SQL (recovery script) + Astro portal provisioning |

---

## 4. Accepted Findings

These behaviors are intentional product decisions. They are NOT open issues or unresolved vulnerabilities.

See `.planning/phases/53-security-rollout-acceptance/53-RISK-REGISTER.md` for the full accepted-risk ledger including current guardrails and follow-up tracking.

| # | Finding | Decision | Rationale |
|---|---------|----------|-----------|
| A-01 | Passwordless employee portal sign-in | Accepted — intentional product decision | Employees access the portal via public card chooser without a password. This was an explicit v7.1 milestone decision. |
| A-02 | Local-only portal logout | Accepted — intentional product decision | Portal sign-out uses `scope: 'local'`, ending the portal session without invalidating the global Supabase session. Locked in Phase 39 decision. |

---

## 5. Open Blockers / Missing Evidence

Record any failed checks, timed-out verification steps, or missing live evidence here during the rollout window.

| # | Item | Status | Notes |
|---|------|--------|-------|
| OB-01 | Live SQL rollout not yet applied | Pending operator action | All three Phase 50-52 SQL files must be applied in Supabase SQL Editor; recovery script conditional only |
| OB-02 | `test/phase52/portal_recovery_contract_test.dart` timed out in sandbox | Open | Focused execution timed out repeatedly in the planning sandbox; must be re-run and confirmed green before acceptance closure |
| OB-03 | Astro portal verification (`npm run check`, `npm run build`) | Pending operator action | Must be run from the website project root after SQL rollout |
| OB-04 | Flutter targeted test suite via helper | Pending | Run `tool/security_hardening_acceptance.ps1` to produce green evidence |

---

## 6. Operator Sign-Off

To be filled in after the live rollout window is complete.

| Field | Value |
|-------|-------|
| Operator | _(name or handle)_ |
| Date applied | _(YYYY-MM-DD)_ |
| Phase 50 SQL — no errors | [ ] Confirmed |
| Phase 51 SQL — no errors | [ ] Confirmed |
| Phase 52 SQL — no errors | [ ] Confirmed |
| Recovery script (conditional) | [ ] Not applied / [ ] Applied — see evidence below |
| Flutter acceptance helper — all green | [ ] Confirmed |
| Astro check green | [ ] Confirmed |
| Astro build green | [ ] Confirmed |
| OB-02 portal recovery contract test | [ ] Confirmed green |
| Accepted findings acknowledged | [ ] Confirmed — passwordless portal entry and local-only logout remain intentional |
| Closeout status | [ ] CLOSED — all evidence recorded and accepted |

Recovery script evidence (if applied):
```
(record repaired rows, script output, and approval reference here)
```

---

## Appendix: Reference Links

- Canonical rollout checklist: `docs/security-hardening-rollout.md`
- Acceptance helper: `tool/security_hardening_acceptance.ps1`
- Retained-risk ledger: `.planning/phases/53-security-rollout-acceptance/53-RISK-REGISTER.md`
- Android release runbook (if shipping updated APK): `docs/android-release-runbook.md`
- SQL scripts: `sql/phase_50_kiosk_boundary_hardening_20260325.sql`, `sql/phase_51_admin_session_trust_20260325.sql`, `sql/phase_52_portal_search_minimization_20260325.sql`, `sql/repair_employee_portal_accounts_20260325.sql`
