---
phase: 37
plan: 01
subsystem: portal-backend
tags: [supabase, sql, edge-function, auth, employee-portal]
dependency_graph:
  requires: []
  provides: [employee_portal_accounts, search_portal_employees, resolve_portal_employee, provision-employee-portal-user]
  affects: [phase-38-portal-schedule, phase-39-portal-ui]
tech_stack:
  added: [pg_trgm]
  patterns: [SECURITY DEFINER RPC, hidden synthetic email, one-to-one auth mapping, SECURITY DEFINER Edge Function]
key_files:
  created:
    - sql/phase_37_employee_portal_foundation_20260322.sql
    - supabase/functions/provision-employee-portal-user/index.ts
  modified: []
key_decisions:
  - "Hidden auth email derived from stable employee_id UUID: employee+<uuid>@portal.absenkok.internal"
  - "search_portal_employees returns empty for <2 chars; trigram fallback only for >=3 chars"
  - "Provisioning cleanup: auth user deleted if employee_portal_accounts insert fails"
  - "portal_search_name is a GENERATED ALWAYS AS STORED column — keeps visible name untouched"
metrics:
  duration: 10m
  completed_date: "2026-03-22"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 0
---

# Phase 37 Plan 01: Portal Foundation — Employee Auth Summary

**One-liner:** Additive portal-account contract with indexed name search (prefix + trigram), identity resolver RPC, and server-side provisioning Edge Function using stable hidden UUID-derived auth emails.

## What Was Built

### Task 1 — SQL: Portal Account Contract, Indexed Name Search, Identity Resolver
- `normalize_portal_search_text(text)` — immutable helper that lowercases, trims, and collapses spaces
- `employees.portal_search_name` — `GENERATED ALWAYS AS STORED` computed column; visible `employees.name` untouched
- `CREATE EXTENSION IF NOT EXISTS pg_trgm`
- B-tree prefix index (`text_pattern_ops`) on `portal_search_name` scoped to active, non-archived employees
- Trigram GIN index (`gin_trgm_ops`) on `portal_search_name` with same partial-index scope
- `employee_portal_accounts` table with `employee_id PK → employees`, `auth_user_id UNIQUE`, `auth_email UNIQUE`, RLS (admin read + employee own-row read), no direct anon writes
- `search_portal_employees(search_text, limit_count=8)` — SECURITY DEFINER; prefix-first, trigram fallback for >=3 chars, returns lightweight identity cards with outlet name join; empty result for <2 char queries
- `resolve_portal_employee()` — SECURITY DEFINER; derives auth user from `auth.uid()`, raises on 0 or 2+ active employee matches, returns exactly one employee context for Phase 38 schedule queries

### Task 2 — Edge Function: provision-employee-portal-user
- Mirrors Phase 26 `create-admin-user` pattern; caller must be `app_role=admin`
- Accepts `{ employee_id, password }` only — no raw display fields
- Loads employee row server-side; blocks inactive/archived and already-provisioned employees
- `derivePortalEmail(employeeId)` helper centralizes the `employee+<uuid>@portal.absenkok.internal` rule
- Creates auth user with `email_confirm: true`, `app_role: 'employee_portal'`, `employee_id` in `app_metadata`
- Inserts `employee_portal_accounts` mapping row; rolls back (deletes auth user) if insert fails
- Returns `{ employee_id, employee_name, auth_user_id, created_at }` — password never echoed

## Decisions Made

| # | Decision | Rationale |
|---|----------|-----------|
| 37-01-A | Hidden email: `employee+<uuid>@portal.absenkok.internal` | UUID is stable; name/code are mutable and unsafe as auth keys |
| 37-01-B | GENERATED ALWAYS AS STORED for `portal_search_name` | Keeps normalization at DB layer; visible `name` column unchanged |
| 37-01-C | Trigram fallback gated at >=3 chars | PostgreSQL docs warn short patterns degrade trigram selectivity |
| 37-01-D | Empty result for <2-char queries | Prevents broad scans; matches login UX minimum-length gate |
| 37-01-E | Auth user cleanup on mapping insert failure | Avoids orphaned auth users that would block future reprovisioning |

## Deviations from Plan

None — plan executed exactly as written.

## Operator Instructions (Required Before Phase 38)

Two steps must be completed before any Astro portal UI work runs against production:

1. **Apply SQL migration** in Supabase Dashboard → SQL Editor:
   - File: `sql/phase_37_employee_portal_foundation_20260322.sql`
   - This adds `employee_portal_accounts`, indexes, and both RPCs

2. **Deploy Edge Function:**
   ```bash
   supabase functions deploy provision-employee-portal-user
   ```

## Success Criteria Verification

- [x] Portal provisioning has a deterministic one-to-one auth-user-to-employee contract (`employee_portal_accounts`)
- [x] Indexed employee-name search exists for fast, low-payload portal login discovery (`search_portal_employees`)
- [x] A resolver exists for later portal routes to resolve exactly one employee from auth state (`resolve_portal_employee`)
- [x] An Edge Function exists to provision employee portal users server-side (`provision-employee-portal-user`)

## Self-Check: PASSED

Files exist:
- sql/phase_37_employee_portal_foundation_20260322.sql — FOUND (c520fb7)
- supabase/functions/provision-employee-portal-user/index.ts — FOUND (f0d8111)

Commits:
- c520fb7: feat(37-01): add portal account contract, indexed name search, and identity resolver SQL
- f0d8111: feat(37-01): add provision-employee-portal-user Edge Function
