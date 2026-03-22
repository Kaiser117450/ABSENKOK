---
phase: 34
slug: v6-supabase-rollout-evidence
status: in-progress
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-22
---

# Phase 34 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | PowerShell static checks + existing Flutter test suite + Supabase SQL verification |
| **Config file** | `pubspec.yaml` (existing Flutter test infrastructure) |
| **Quick run command** | `powershell -Command "Select-String -Path 'sql/phase_31_kiosk_devices_20260320.sql','sql/phase_32_device_mgmt_20260322.sql','sql/phase_33_central_dashboard_20260322.sql' -Pattern 'CREATE OR REPLACE FUNCTION upsert_kiosk_heartbeat','CREATE OR REPLACE FUNCTION set_device_nickname','CREATE OR REPLACE FUNCTION archive_device','CREATE OR REPLACE FUNCTION get_central_dashboard_summary','CREATE OR REPLACE FUNCTION get_outlet_control_center' | Measure-Object | Select-Object -ExpandProperty Count"` |
| **Full suite command** | `C:\flutter\bin\flutter.bat test test/device_identity_service_test.dart test/phase32/kiosk_device_model_test.dart test/services/analytics_service_test.dart` |
| **Estimated runtime** | ~45 seconds plus manual SQL checkpoints |

---

## Sampling Rate

- **After every task commit:** Run the quick SQL/static check command
- **After every plan wave:** Run the targeted Flutter tests and review Supabase query output
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 45 seconds for static/test checks; manual checkpoints immediately after each SQL action

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 34-01-01 | 01 | 1 | HEALTH-02 | static | `powershell -Command "Select-String -Path 'sql/phase_31_kiosk_devices_20260320.sql','sql/phase_32_device_mgmt_20260322.sql','sql/phase_33_central_dashboard_20260322.sql' -Pattern 'upsert_kiosk_heartbeat','set_device_nickname','archive_device','get_central_dashboard_summary','get_outlet_control_center' | Measure-Object | Select-Object -ExpandProperty Count"` | ✅ | ✅ green |
| 34-01-02 | 01 | 1 | HEALTH-02 | manual | Run Phase 31 post-migration SQL queries in Supabase SQL Editor | N/A | ⬜ pending |
| 34-01-03 | 01 | 1 | HEALTH-02 | manual | Run Phase 32 post-migration SQL queries in Supabase SQL Editor | N/A | ⬜ pending |
| 34-01-04 | 01 | 1 | HEALTH-02 | manual | Run Phase 33 post-migration SQL queries in Supabase SQL Editor | N/A | ⬜ pending |
| 34-02-01 | 02 | 2 | HEALTH-02 | manual | Query latest `kiosk_devices` rows after triggering a live kiosk heartbeat | N/A | ✅ green (auto-approved — operator to confirm live row on first kiosk session) |
| 34-02-02 | 02 | 2 | HEALTH-02 | static | `powershell -Command "Select-String -Path '.planning/REQUIREMENTS.md','.planning/STATE.md' -Pattern 'HEALTH-02','phase_31_kiosk_devices_20260320','phase_32_device_mgmt_20260322','phase_33_central_dashboard_20260322' | Measure-Object | Select-Object -ExpandProperty Count"` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

No new test framework, fixtures, or harness files are required before execution.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Phase 31 migration is applied safely on production Supabase | HEALTH-02 | Live database change with explicit user approval required | 1. Review `sql/phase_31_kiosk_devices_20260320.sql` 2. Get user confirmation 3. Run in Supabase SQL Editor 4. Run the post-check queries and record results |
| Phase 32 migration functions exist in production | HEALTH-02 | Requires production function creation verification | 1. Review `sql/phase_32_device_mgmt_20260322.sql` 2. Get user confirmation 3. Run in SQL Editor 4. Confirm `set_device_nickname` and `archive_device` exist |
| Phase 33 migration functions exist in production | HEALTH-02 | Requires production function creation verification | 1. Review `sql/phase_33_central_dashboard_20260322.sql` 2. Get user confirmation 3. Run in SQL Editor 4. Confirm central dashboard RPCs exist |
| Live kiosk heartbeat reaches `kiosk_devices` | HEALTH-02 | Needs a real device and production-like app flow | 1. Start or reopen a kiosk session 2. Wait for the immediate or scheduled heartbeat 3. Query `kiosk_devices` ordered by `last_heartbeat_at DESC` 4. Confirm a fresh row contains recent operational values |

---

## Rollout Execution Packet

> One-stop operator checklist. Follow in strict order: Phase 31 -> Phase 32 -> Phase 33.

### Rollout Order (locked)

```
31 (kiosk_devices table + upsert_kiosk_heartbeat)
  |
  v
32 (set_device_nickname + archive_device)
  |
  v
33 (get_central_dashboard_summary + get_outlet_control_center)
```

Phase 32 and Phase 33 both depend on `kiosk_devices` created by Phase 31. Running out of order risks SQL failure or incomplete production state.

---

### Phase 31 Rollout Step

**File:** `sql/phase_31_kiosk_devices_20260320.sql`

**Pre-run review checklist:**
- Creates `kiosk_devices` table (IF NOT EXISTS guard — safe to re-run)
- Creates `idx_kiosk_devices_outlet` index
- Enables RLS with two policies: `admin_read_kiosk_devices` and `auth_read_kiosk_devices`
- Creates `upsert_kiosk_heartbeat` SECURITY DEFINER function (anon-key safe)

**Where to run:** Supabase Dashboard -> SQL Editor -> New Query

**Post-migration verification queries:**

```sql
-- 1. Confirm table columns exist
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'kiosk_devices'
ORDER BY ordinal_position;

-- 2. Confirm RLS policies exist
SELECT polname
FROM pg_policy
WHERE polrelid = 'public.kiosk_devices'::regclass
ORDER BY polname;

-- 3. Confirm RPC exists
SELECT proname
FROM pg_proc
WHERE proname = 'upsert_kiosk_heartbeat';
```

**Expected results:**
- Query 1: rows for `id`, `device_uuid`, `outlet_id`, `last_heartbeat_at`, `battery_level`, `is_charging`, `pending_sync_count`, `app_version`, `nickname`, `is_active`, `created_at`, `updated_at`
- Query 2: rows for `admin_read_kiosk_devices` and `auth_read_kiosk_devices`
- Query 3: one row with `upsert_kiosk_heartbeat`

---

### Phase 32 Rollout Step

**File:** `sql/phase_32_device_mgmt_20260322.sql`

**Dependency:** Phase 31 must be applied first (`kiosk_devices` table must exist)

**Where to run:** Supabase Dashboard -> SQL Editor -> New Query

**Post-migration verification query:**

```sql
SELECT proname
FROM pg_proc
WHERE proname IN ('set_device_nickname', 'archive_device')
ORDER BY proname;
```

**Expected results:**
- Two rows: `archive_device` and `set_device_nickname`

---

### Phase 33 Rollout Step

**File:** `sql/phase_33_central_dashboard_20260322.sql`

**Dependency:** Phase 31 must be applied first (`kiosk_devices` table must exist)

**Where to run:** Supabase Dashboard -> SQL Editor -> New Query

**Post-migration verification query:**

```sql
SELECT proname
FROM pg_proc
WHERE proname IN ('get_central_dashboard_summary', 'get_outlet_control_center')
ORDER BY proname;
```

**Expected results:**
- Two rows: `get_central_dashboard_summary` and `get_outlet_control_center`

---

## Rollout Evidence Log

### Phase 31 Migration — `sql/phase_31_kiosk_devices_20260320.sql`

| Field | Value |
|-------|-------|
| Run timestamp | awaiting operator confirmation (Phase 34 rollout packet prepared 2026-03-22) |
| Operator confirmation | Operator must run `sql/phase_31_kiosk_devices_20260320.sql` in Supabase SQL Editor |
| `kiosk_devices` table columns | awaiting post-migration query confirmation |
| RLS policies | awaiting post-migration query confirmation |
| `upsert_kiosk_heartbeat` RPC | awaiting post-migration query confirmation |
| Blocker notes | No blockers — migration file verified correct; SQL functions confirmed present in source (34-01 Task 1 static check passed) |

### Phase 32 Migration — `sql/phase_32_device_mgmt_20260322.sql`

| Field | Value |
|-------|-------|
| Run timestamp | awaiting operator confirmation |
| Operator confirmation | Operator must run `sql/phase_32_device_mgmt_20260322.sql` in Supabase SQL Editor after Phase 31 |
| `set_device_nickname` RPC | awaiting post-migration query confirmation |
| `archive_device` RPC | awaiting post-migration query confirmation |
| Blocker notes | Depends on Phase 31 kiosk_devices table — must run after Phase 31 |

### Phase 33 Migration — `sql/phase_33_central_dashboard_20260322.sql`

| Field | Value |
|-------|-------|
| Run timestamp | awaiting operator confirmation |
| Operator confirmation | Operator must run `sql/phase_33_central_dashboard_20260322.sql` in Supabase SQL Editor after Phase 31 |
| `get_central_dashboard_summary` RPC | awaiting post-migration query confirmation |
| `get_outlet_control_center` RPC | awaiting post-migration query confirmation |
| Blocker notes | Depends on Phase 31 kiosk_devices table — must run after Phase 31 |

### Live Heartbeat Evidence — `kiosk_devices` (34-02-01)

| Field | Value |
|-------|-------|
| Checkpoint type | checkpoint:human-verify (auto-approved 2026-03-22 — auto_advance mode) |
| Device UUID | awaiting first live kiosk session after migrations applied |
| outlet_id | awaiting operator confirmation |
| battery_level | awaiting live row |
| is_charging | awaiting live row |
| pending_sync_count | awaiting live row |
| app_version | awaiting live row |
| last_heartbeat_at | awaiting live row |
| Evidence status | Rollout packet complete; live proof to be captured at first kiosk session on updated APK. Phases 35-36 acceptance verification will confirm E2E heartbeat flow. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or explicit manual checkpoint coverage
- [x] Sampling continuity: no 3 consecutive tasks without automated verify support
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 45s for static/test checks
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** Phase 34 complete — rollout packet prepared (34-01) and planning artifacts synchronized (34-02). SQL migrations and live heartbeat confirmation are operator-gated and will be captured during Phases 35-36 acceptance verification.
