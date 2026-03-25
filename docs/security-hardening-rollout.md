# Security Hardening Rollout Checklist — v7.1

**Scope:** Phase 53 rollout and acceptance only.
No new hardening is introduced in this phase. The implementation already shipped in Phases 50-52. This checklist gives operators one auditable path for applying those changes to the live production database and verifying the result across all three surfaces: SQL, Astro portal, and Flutter app.

---

## 1. Scope and Boundary

Phase 53 is rollout-and-acceptance only. It does not add new security controls.

The hardening spans three surfaces:

| Surface | Phase | What changed |
|---------|-------|--------------|
| Supabase (SQL) | 50 | Kiosk activation and heartbeat now require a confirmed device UUID binding; `set_device_nickname` and `archive_device` are role-gated |
| Supabase (SQL) | 51 | Admin session trust now relies on `app_metadata` (server-issued) rather than writable `user_metadata`; a null-role caller can no longer reach analytics |
| Supabase (SQL) | 52 | Portal public chooser is narrowed to a minimal DTO, 5-result cap, 3-character minimum, 64-character input limit; portal route middleware enforces auth before downstream handlers |
| Astro portal | 52 | Middleware redirects before `next()`; `resolvePortalEmployee()` trusts the cached middleware boundary |
| Flutter app | 50-52 | Kiosk model parsing degrades safely on malformed UUIDs and timestamps; admin session claims validated against `app_metadata` |

**What this checklist does not cover:** rollback instructions, destructive migrations, or redesign of the accepted passwordless portal boundary.

---

## 2. Prerequisites

Before applying any SQL to production:

- [ ] **Production approval obtained.** The live attendance database (`tmapxdftdhxovthgbhww`) serves 4 active outlets. Every SQL step below is additive only (no DROP TABLE, no column removal, no data rewrites).
- [ ] **Additive-only rule confirmed.** Read each migration file before applying. If it contains anything other than CREATE OR REPLACE FUNCTION / CREATE INDEX / ALTER TABLE ADD COLUMN (with no data-altering statements), stop and escalate.
- [ ] **Astro portal check is green locally.** Run `npm run check` from the website project root and confirm zero errors before the rollout window.
- [ ] **Flutter tests are green locally.** Run `flutter test test/phase50/kiosk_device_model_test.dart test/phase51/admin_session_claims_test.dart test/phase51/sql_role_guard_contract_test.dart test/phase52/portal_recovery_contract_test.dart` and confirm all pass.
- [ ] **Android release runbook reviewed.** See `docs/android-release-runbook.md` for the Flutter release lane prerequisites before shipping any updated APK.

---

## 3. Rollout Sequence

Apply in this exact order. Do not skip steps. Do not apply the recovery script unless Appendix A conditions are met.

### Step 1: Apply Phase 50 kiosk boundary hardening

- **File:** `sql/phase_50_kiosk_boundary_hardening_20260325.sql`
- **Location:** Supabase Dashboard -> SQL Editor -> project `tmapxdftdhxovthgbhww` -> New Query
- **Action:** Paste and run the file contents. Confirm no errors in the output panel.
- **What it adds:** `activate_kiosk_device` RPC enforces UUID binding; `upsert_kiosk_heartbeat` only refreshes an existing active binding; `set_device_nickname` and `archive_device` require authenticated `admin` or scoped `kepala_gerai` callers.
- [ ] Step 1 complete — SQL applied, no errors

### Step 2: Apply Phase 51 admin session trust hardening

- **File:** `sql/phase_51_admin_session_trust_20260325.sql`
- **Location:** Supabase Dashboard -> SQL Editor -> same project -> New Query
- **Action:** Paste and run the file contents. Confirm no errors.
- **What it adds:** Analytics RPCs now read role from `app_metadata` (server-issued) rather than `user_metadata`; a null-role JWT can no longer reach privileged outlet data.
- [ ] Step 2 complete — SQL applied, no errors

### Step 3: Apply Phase 52 portal chooser minimization

- **File:** `sql/phase_52_portal_search_minimization_20260325.sql`
- **Location:** Supabase Dashboard -> SQL Editor -> same project -> New Query
- **Action:** Paste and run the file contents. Confirm no errors.
- **What it adds:** `search_portal_employees` now returns only the minimal chooser DTO (no PII beyond display name), caps at 5 results, requires 3 normalized characters, and rejects inputs over 64 characters.
- [ ] Step 3 complete — SQL applied, no errors

> **Recovery script:** `sql/repair_employee_portal_accounts_20260325.sql` is NOT part of the routine rollout. See Appendix A for the conditional use case.

---

## 4. Astro Portal Verification Gates

Run both commands from the website project root after completing the SQL steps above.

```powershell
npm run check
npm run build
```

- `npm run check` runs `astro check` — confirms TypeScript types and SSR component contracts are valid across the portal surface.
- `npm run build` runs `astro build` — confirms the portal builds cleanly with the hardened middleware, chooser endpoint, and recovery path in place.

- [ ] `npm run check` passed with zero errors
- [ ] `npm run build` passed with no build failures

---

## 5. Flutter Verification Gates

The existing Android release runbook documents the full Flutter release lane. Do not invent a new packaging flow for this rollout; follow `docs/android-release-runbook.md`.

For targeted hardening regression coverage, run:

```powershell
C:\flutter\bin\flutter.bat test `
  test/phase50/kiosk_device_model_test.dart `
  test/phase51/admin_session_claims_test.dart `
  test/phase51/sql_role_guard_contract_test.dart `
  test/phase52/portal_recovery_contract_test.dart
```

- [ ] All four targeted test files pass
- [ ] Release lane reviewed per `docs/android-release-runbook.md` if an updated APK is being shipped alongside this rollout

---

## 6. Evidence for the Closeout Packet

After completing Steps 1-5, record the following evidence. This evidence is required for Phase 53 acceptance closure.

| Evidence item | Expected value |
|---------------|----------------|
| Phase 50 SQL application | Supabase SQL Editor: no errors, function `activate_kiosk_device` now exists |
| Phase 51 SQL application | Supabase SQL Editor: no errors, analytics RPC role guard updated |
| Phase 52 SQL application | Supabase SQL Editor: no errors, `search_portal_employees` returns narrowed DTO |
| `npm run check` result | Zero errors |
| `npm run build` result | Build succeeded, no warnings treated as errors |
| Flutter targeted tests | All four files green |
| Accepted findings on record | Passwordless portal entry and local-only portal logout remain intentional product decisions |
| Recovery script status | Not applied (or: applied for an approved repair case — see Appendix A) |

Keep this evidence in the Phase 53 acceptance packet (`.planning/phases/53-security-rollout-acceptance/`).

---

## Appendix A: Conditional Recovery Script

`sql/repair_employee_portal_accounts_20260325.sql` is an operator-only repair tool. It is NOT part of the normal rollout path above.

**Use it only when all of the following are true:**

1. An `employee_portal_accounts` row exists with a broken or missing `auth_user_id` link.
2. The affected employee's hidden auth user (`employee+<uuid>@portal.absenkok.internal`) has confirmed `employee_portal` app metadata that matches the expected `employee_id`.
3. A human operator with production approval has reviewed the script and confirmed it addresses the identified broken rows.

**What the script does:** It restores confirmed `employee_portal` identities with matching `employee_id` metadata. It skips any row where there is a metadata conflict, rather than repointing `auth_user_id` to an unconfirmed account.

**Evidence required if applied:** Record which rows were repaired, confirm the script output, and note the approval reference in the closeout packet.

---

## Accepted Product Decisions (Not Regressions)

The following behaviors remain intentional and should not be treated as unresolved findings:

- **Passwordless employee portal sign-in:** Employees access the portal by selecting their card from the public chooser. This requires no password. This is a deliberate product decision for this milestone.
- **Local-only portal logout:** Portal sign-out uses `scope: 'local'`, ending the portal session without invalidating the global Supabase auth session. This is intentional per the Phase 39 decision.

These items must appear in the acceptance evidence as accepted findings, not as open issues.
