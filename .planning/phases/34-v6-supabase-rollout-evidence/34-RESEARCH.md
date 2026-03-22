# Phase 34: v6.0 Supabase Rollout Evidence - Research

**Researched:** 2026-03-22
**Domain:** Production Supabase rollout, additive SQL migration ordering, and milestone evidence capture
**Confidence:** HIGH (grounded in the existing SQL files, phase summaries, milestone audit, and project database safety rules)

---

## Summary

Phase 34 is not a new feature-build phase. The code and SQL for phases 31-33 already exist, but the milestone failed audit because there is no recorded production rollout proof for the three v6.0 SQL migrations and no live evidence that the new `kiosk_devices` path is working in production.

The correct closure strategy is:

1. Roll out the three existing SQL migrations in dependency order: Phase 31 -> Phase 32 -> Phase 33
2. Verify each schema/function set immediately after application
3. Capture one live heartbeat row in `kiosk_devices`
4. Update planning artifacts only after real evidence exists

This phase must remain operator-guided because the production database is live and `STATE.md` explicitly requires user confirmation before every database change.

---

## Phase Requirement

| ID | Description | Research Support |
|----|-------------|------------------|
| HEALTH-02 | Kiosk syncs heartbeat metrics to a dedicated `kiosk_devices` table instead of `outlets`. | Phase 31 already authored the table + RPC, Phase 32 removed the old bridge write, and the audit shows the missing piece is rollout proof, not new implementation. |

---

## Current State Analysis

### 1. The migration chain already exists in the repo

The three required SQL files are present and additive:

- `sql/phase_31_kiosk_devices_20260320.sql`
  - creates `kiosk_devices`
  - creates `upsert_kiosk_heartbeat`
  - adds SELECT policies for dashboard access
- `sql/phase_32_device_mgmt_20260322.sql`
  - creates `set_device_nickname`
  - creates `archive_device`
- `sql/phase_33_central_dashboard_20260322.sql`
  - creates `get_central_dashboard_summary`
  - creates `get_outlet_control_center`

This means Phase 34 should not re-design SQL. It should validate rollout order, run the existing migrations safely, and prove the database now matches the shipped app code.

### 2. There is a hard dependency order

The rollout order cannot be arbitrary:

1. Phase 31 must go first because it creates `kiosk_devices` and `upsert_kiosk_heartbeat`
2. Phase 32 depends on the `kiosk_devices` table existing
3. Phase 33 aggregates from `kiosk_devices`, so it also depends on Phase 31

Applying Phase 32 or 33 before Phase 31 risks immediate SQL failure or incomplete production state.

### 3. The app code is already wired to these database objects

The current codebase already expects the SQL to exist:

- `HeartbeatService` writes to `upsert_kiosk_heartbeat`
- `AdminDashboardScreen` reads `kiosk_devices` and calls `set_device_nickname` / `archive_device`
- `CentralDashboardScreen` and `AnalyticsService` depend on `get_central_dashboard_summary` and `get_outlet_control_center`

Because the feature wiring already exists, a missing SQL rollout is a production-integrity gap, not a coding gap.

### 4. Audit failure is evidence-driven, not implementation-driven

The milestone audit identified four proof gaps that Phase 34 must close:

- no artifact that the three SQL migrations were applied in Supabase
- no live evidence that a heartbeat reaches `kiosk_devices`
- planning docs still say the migrations "must be applied before deployment"
- `HEALTH-02` remains pending because the system lacks deployment proof

---

## Project Constraints That Must Shape the Plan

From `STATE.md`:

- the production database is serving 4 active outlets
- additive migrations only
- user confirmation is mandatory before each database change
- Android kiosk uptime must not be disrupted by avoidable schema mistakes

Operationally, this means the plan should:

- avoid speculative SQL edits unless verification proves the existing migration files are insufficient
- separate schema rollout from live app proof
- capture evidence immediately after each action
- never mark requirements complete based on assumption

---

## Recommended Execution Strategy

### Step 1: Build a rollout packet before touching Supabase

Before any database action, execution should prepare:

- the exact SQL file order
- the exact verification queries after each migration
- the exact rollback/escalation rule if a migration fails

This keeps production changes controlled and prevents improvising against a live database.

### Step 2: Apply the migrations one at a time with explicit confirmation

Each migration should have its own blocking checkpoint:

1. review SQL file
2. confirm user approval
3. run in Supabase SQL Editor
4. run the post-check queries
5. capture results in planning artifacts

This satisfies the database safety rule and makes the resulting evidence auditable.

### Step 3: Prove live data reaches `kiosk_devices`

Schema existence is not enough. The phase must prove the app is actually using the new path.

Best proof:

- trigger or observe a live kiosk heartbeat
- query `kiosk_devices` for the most recent row
- record `device_uuid`, `outlet_id`, `last_heartbeat_at`, and operational fields such as battery/sync counts

If no live heartbeat arrives, the phase should not mark HEALTH-02 complete even if the SQL objects exist.

### Step 4: Synchronize planning artifacts only after evidence exists

Only after migrations and live heartbeat proof succeed should execution update:

- `REQUIREMENTS.md` for HEALTH-02
- `STATE.md` to replace "must be applied" notes with applied-on evidence
- `34-VALIDATION.md` to mark rollout verification steps green

This prevents the planning layer from drifting ahead of reality again.

---

## Verification Queries to Reuse During Execution

### After Phase 31 migration

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'kiosk_devices'
ORDER BY ordinal_position;

SELECT polname
FROM pg_policy
WHERE polrelid = 'public.kiosk_devices'::regclass
ORDER BY polname;

SELECT proname
FROM pg_proc
WHERE proname = 'upsert_kiosk_heartbeat';
```

### After Phase 32 migration

```sql
SELECT proname
FROM pg_proc
WHERE proname IN ('set_device_nickname', 'archive_device')
ORDER BY proname;
```

### After Phase 33 migration

```sql
SELECT proname
FROM pg_proc
WHERE proname IN ('get_central_dashboard_summary', 'get_outlet_control_center')
ORDER BY proname;
```

### Live heartbeat proof

```sql
SELECT device_uuid, outlet_id, battery_level, is_charging, pending_sync_count, app_version, last_heartbeat_at
FROM kiosk_devices
ORDER BY last_heartbeat_at DESC NULLS LAST
LIMIT 5;
```

---

## Pitfalls

### Pitfall 1: Treating rollout evidence as a pure docs update

The audit failed because proof was missing. Updating docs without real Supabase confirmation just recreates the same gap.

### Pitfall 2: Running all three SQL files in one blind batch

If a later migration fails, the operator loses clarity about what succeeded and what still needs verification. Run them one at a time.

### Pitfall 3: Marking HEALTH-02 complete before a live heartbeat exists

Schema objects alone do not prove the kiosk app is using them correctly.

### Pitfall 4: Editing the SQL files during rollout unless there is concrete failure evidence

The authored SQL already matches the shipped code paths. Do not mutate production-facing migrations on instinct.

### Pitfall 5: Forgetting the downstream dependencies

Phase 35 and Phase 36 depend on this rollout being proven. If Phase 34 does not capture clear evidence, the later acceptance phases cannot audit cleanly.

---

## Validation Architecture

### Dimension 1: Schema rollout integrity

- each migration is applied in the correct order
- each expected table/function/policy exists immediately after application
- no destructive SQL is introduced

### Dimension 2: Live path proof

- a kiosk heartbeat produces a recent row in `kiosk_devices`
- the proof row shows operational fields, not just an empty shell record

### Dimension 3: Regression safety

- existing repository tests that cover the relevant code paths remain runnable
- no app-code changes are required unless rollout evidence exposes a real defect

### Dimension 4: Evidence integrity

- validation artifacts record what was applied, when, and how it was verified
- `REQUIREMENTS.md` and `STATE.md` are only updated after proof exists

### Recommended task split

- Plan 01: controlled Supabase rollout and post-migration verification
- Plan 02: live heartbeat proof and planning-state synchronization

This split keeps the production DB changes in wave 1 and the documentation/evidence closeout in wave 2.

---

## Sources

### Primary

- `.planning/v6.0-MILESTONE-AUDIT.md`
- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/STATE.md`
- `sql/phase_31_kiosk_devices_20260320.sql`
- `sql/phase_32_device_mgmt_20260322.sql`
- `sql/phase_33_central_dashboard_20260322.sql`
- `.planning/phases/31-device-identity-foundation/31-02-SUMMARY.md`
- `.planning/phases/32-multi-device-dashboard/32-02-SUMMARY.md`
- `.planning/phases/33-multi-outlet-control-center/33-02-SUMMARY.md`

### Supporting

- `lib/services/heartbeat_service.dart`
- `lib/screens/admin/admin_dashboard_screen.dart`
- `lib/screens/admin/central_dashboard_screen.dart`
- `lib/services/analytics_service.dart`

---

## RESEARCH COMPLETE
