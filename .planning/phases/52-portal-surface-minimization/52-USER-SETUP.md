# Phase 52: User Setup Required

**Generated:** 2026-03-25
**Phase:** 52-portal-surface-minimization
**Status:** Incomplete

Complete these items for the Phase 52 portal hardening to function in production. The repo changes are done; the live Supabase project still needs explicit human review before any SQL is applied.

## Environment Variables

None.

## Dashboard Configuration

- [ ] **Apply the public chooser hardening migration**
  - Location: Supabase Dashboard -> SQL Editor -> New Query
  - Set to: Run `sql/phase_52_portal_search_minimization_20260325.sql`
  - Notes: This patch is additive only. Review it first, then apply it with production approval because the live attendance system is already running.

- [ ] **Run the portal recovery script only when recovery is actually needed**
  - Location: Supabase Dashboard -> SQL Editor -> New Query
  - Set to: Run `sql/repair_employee_portal_accounts_20260325.sql`
  - Notes: This is an operator recovery tool, not a routine rollout step. Use it only when `employee_portal_accounts` repair is required and only after explicit approval in the correct recovery scenario.

## Verification

After completing setup, verify with:

```bash
# Inspect the two SQL artifacts that require human review
Select-String -Path sql/phase_52_portal_search_minimization_20260325.sql,sql/repair_employee_portal_accounts_20260325.sql -Pattern "search_portal_employees|employee_portal_accounts|employee_portal|LIMIT 5|email_confirmed_at"
```

Expected results:
- The chooser migration only exposes the narrowed public search DTO and the tighter query caps.
- The recovery script requires confirmed `employee_portal` identities with explicit `employee_id` metadata and does not repoint `auth_user_id` on conflict.
- Supabase SQL Editor has applied the search hardening only after review, and the recovery script is kept for operator-led repair scenarios rather than routine rollout.

---

**Once all items complete:** Mark status as "Complete" at top of file.
