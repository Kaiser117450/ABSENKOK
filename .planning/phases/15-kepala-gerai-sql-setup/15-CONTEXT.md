# Phase 15: Kepala Gerai SQL Setup - Context

**Gathered:** 2026-03-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver SQL scripts for Supabase SQL Editor to manage admin roles: promote user to Kepala Gerai (outlet-scoped), promote to full Admin, and demote/revoke any role. Zero Flutter code — all role handling already implemented in app.

</domain>

<decisions>
## Implementation Decisions

### Account Creation Flow
- User creates Supabase Auth account **separately** in Supabase Auth dashboard (email/password)
- SQL script only **promotes** an existing auth user — does NOT create accounts
- If email not found in auth.users, script should fail with clear error message

### Script Format
- Simple SQL block with variables at the top (not RPC function)
- User changes 2 values: email address + outlet name
- Copy-paste into Supabase SQL Editor → Run → Done
- Clear comments in Indonesian explaining each variable

### Deliverables (3 scripts)
1. **Promote to Kepala Gerai** — Sets `app_role = 'kepala_gerai'` + `managed_outlet_id = <resolved_outlet_id>` in auth metadata
2. **Promote to Admin** — Sets `app_role = 'admin'` in auth metadata (no outlet scoping)
3. **Demote/Revoke** — Removes `app_role` and `managed_outlet_id` from auth metadata

### Metadata Storage
- Role stored in `raw_app_meta_data` on `auth.users` table (Flutter reads from `appMetadata`)
- Flutter login checks both `userMetadata` AND `appMetadata` for `app_role` — use `appMetadata` (more secure, not user-editable)
- Kepala Gerai also needs `managed_outlet_id` in `appMetadata` — resolved from outlet name

### Error Handling
- Script validates email exists in auth.users before updating
- Script validates outlet name exists in public.outlets before resolving to ID
- Clear RAISE NOTICE messages on success/failure

### Claude's Discretion
- Exact SQL syntax (DO block vs function)
- Whether to wrap in transaction
- Output format of success messages

</decisions>

<specifics>
## Specific Ideas

- User said: "setup cepat/code cepat yang saya tinggal tambahkan gmail kepala gerai dan dia jadi kepala gerai di toko yang terdaftar"
- Scripts should feel like fill-in-the-blank templates — minimal editing required
- 4 outlets currently in production — this is a small-scale operation

</specifics>

<code_context>
## Existing Code Insights

### Auth Metadata Fields (used by Flutter)
- `app_role`: 'admin' | 'kepala_gerai' — checked in `admin_login_screen.dart:61-62`
- `managed_outlet_id`: UUID string — checked in `admin_login_screen.dart:78-79`
- Read from both `userMetadata` and `appMetadata` with appMetadata priority

### Flutter Role Handling (already implemented)
- `lib/screens/admin/admin_login_screen.dart:59-90` — Login validates role, reads managed_outlet_id
- `lib/providers/app_provider.dart:10-42` — AppState has isAdmin, isKepalaGerai, managedOutletId
- `lib/app.dart:47-85` — Router guards: kepala_gerai blocked from /admin/outlets
- `lib/screens/admin/admin_shell.dart:42` — Bottom nav hides Gerai tab for kepala_gerai
- `lib/screens/admin/admin_dashboard_screen.dart:104-105` — Dashboard filters by managedOutletId
- `lib/screens/admin/admin_employees_screen.dart:86-87` — Employees filtered by managedOutletId

### Supabase Tables
- `auth.users` — Has `raw_app_meta_data` JSONB column for app metadata
- `public.outlets` — Has `id` (UUID), `name` (text), `is_active` (bool)
- Outlet names are case-sensitive in DB — script should do case-insensitive match

### Integration Points
- Script output (updated metadata) consumed by Flutter at login time
- No real-time sync needed — user just logs in after promotion

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 15-kepala-gerai-sql-setup*
*Context gathered: 2026-03-12*
