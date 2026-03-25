# Phase 53: User Setup Required

**Generated:** 2026-03-25
**Phase:** 53-security-rollout-acceptance
**Status:** Incomplete

Complete these items before Phase 53 acceptance can close. The repo changes from Phases 50-52 are complete. The live Supabase project (`tmapxdftdhxovthgbhww`) still needs each additive SQL migration applied manually with explicit production approval.

For the full operator checklist — including prerequisites, verification commands, and the evidence table — see `docs/security-hardening-rollout.md`.

---

## Production Project

- **Project ID:** `tmapxdftdhxovthgbhww`
- **Region:** ap-south-1 (Mumbai)
- **Status:** ACTIVE_HEALTHY — live attendance system serving 4 active outlets

Every SQL step below is additive only. Review each file before running it.

---

## Supabase SQL Steps (in order)

Follow the exact sequence defined in `docs/security-hardening-rollout.md` Section 3.

- [ ] **Step 1: Apply Phase 50 kiosk boundary hardening**
  - Location: Supabase Dashboard -> SQL Editor -> project `tmapxdftdhxovthgbhww` -> New Query
  - File: `sql/phase_50_kiosk_boundary_hardening_20260325.sql`
  - Notes: Additive only. Adds `activate_kiosk_device` binding and role gates for `set_device_nickname` and `archive_device`. Review before applying.

- [ ] **Step 2: Apply Phase 51 admin session trust hardening**
  - Location: Supabase Dashboard -> SQL Editor -> project `tmapxdftdhxovthgbhww` -> New Query
  - File: `sql/phase_51_admin_session_trust_20260325.sql`
  - Notes: Additive only. Moves analytics role trust from `user_metadata` to `app_metadata`. Review before applying.

- [ ] **Step 3: Apply Phase 52 portal chooser minimization**
  - Location: Supabase Dashboard -> SQL Editor -> project `tmapxdftdhxovthgbhww` -> New Query
  - File: `sql/phase_52_portal_search_minimization_20260325.sql`
  - Notes: Additive only. Narrows `search_portal_employees` to the minimal chooser DTO with 5-result cap, 3-char minimum, 64-char input limit. Review before applying.

### Conditional: Portal Account Recovery (not a routine step)

`sql/repair_employee_portal_accounts_20260325.sql` must NOT be run as part of the standard rollout above.

- [ ] **[CONDITIONAL] Run portal account recovery script only in an approved repair scenario**
  - Location: Supabase Dashboard -> SQL Editor -> project `tmapxdftdhxovthgbhww` -> New Query
  - File: `sql/repair_employee_portal_accounts_20260325.sql`
  - Notes: Use only when a broken `employee_portal_accounts` row needs repair and only when the affected employee's hidden auth user has confirmed `employee_portal` metadata matching `employee_id`. The script skips conflicting rows rather than repointing mappings. Requires explicit approval before running.

---

## Acceptance Evidence Checklist

Collect this evidence during the rollout window and attach it to the Phase 53 closeout packet.

- [ ] **SQL application confirmation**
  - Confirm all three additive migrations applied with no errors in Supabase SQL Editor
  - Note the date and time of each application

- [ ] **Astro verification results**
  - Run from the website project root: `npm run check`
  - Run from the website project root: `npm run build`
  - Record: zero errors on `check`, clean build on `build`

- [ ] **Flutter verification / release-lane confirmation**
  - Run targeted tests:
    ```powershell
    C:\flutter\bin\flutter.bat test `
      test/phase50/kiosk_device_model_test.dart `
      test/phase51/admin_session_claims_test.dart `
      test/phase51/sql_role_guard_contract_test.dart `
      test/phase52/portal_recovery_contract_test.dart
    ```
  - Confirm all four test files pass
  - If an updated APK is being shipped: follow `docs/android-release-runbook.md` for the full release lane

- [ ] **Accepted-risk notes (intentional, not regressions)**
  - Passwordless employee portal sign-in remains by product decision
  - Local-only portal logout (`scope: 'local'`) remains by product decision
  - These items must appear as accepted findings in the closeout packet, not as open issues

---

**Once all items complete:** Mark `Status: Incomplete` above as `Status: Complete` and add the closeout date.
