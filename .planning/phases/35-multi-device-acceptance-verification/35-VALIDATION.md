---
phase: 35
slug: multi-device-acceptance-verification
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-22
---

# Phase 35 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Existing Flutter tests + PowerShell static checks + live Supabase SQL verification |
| **Config file** | `pubspec.yaml` plus planning artifacts in `.planning/phases/35-multi-device-acceptance-verification/` |
| **Quick run command** | `powershell -Command "Select-String -Path 'lib/services/device_identity_service.dart','lib/services/heartbeat_service.dart','lib/screens/admin/admin_dashboard_screen.dart','sql/phase_31_kiosk_devices_20260320.sql','sql/phase_32_device_mgmt_20260322.sql' -Pattern 'getOrCreateDeviceUuid','upsert_kiosk_heartbeat','from\\(''kiosk_devices''\\)','set_device_nickname','archive_device' | Measure-Object | Select-Object -ExpandProperty Count"` |
| **Full suite command** | `C:\flutter\bin\flutter.bat test test/device_identity_service_test.dart test/phase32/kiosk_device_model_test.dart` |
| **Estimated runtime** | ~30 seconds for static/test checks plus manual live checkpoints |

---

## Sampling Rate

- **After every task commit:** Run the quick static check command
- **After every plan wave:** Run `C:\flutter\bin\flutter.bat test test/device_identity_service_test.dart test/phase32/kiosk_device_model_test.dart`
- **Before `$gsd-verify-work`:** Full live evidence plus the targeted Flutter tests must be green
- **Max feedback latency:** 30 seconds for local checks; each live checkpoint should be recorded immediately after execution

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 35-01-01 | 01 | 1 | HEALTH-01, HEALTH-03 | static | `powershell -Command "Select-String -Path '.planning/phases/35-multi-device-acceptance-verification/35-VALIDATION.md' -Pattern 'Prerequisite Check','UUID Persistence','Dual-Device Same-Outlet','SELECT device_uuid' | Measure-Object | Select-Object -ExpandProperty Count"` | ✅ | ⬜ pending |
| 35-01-02 | 01 | 1 | HEALTH-01 | manual | Review Phase 34 evidence, then run the UUID baseline and post re-setup queries in Supabase SQL Editor | N/A | ⬜ pending |
| 35-01-03 | 01 | 1 | HEALTH-03 | manual | Run the same-outlet dual-device query and compare it with the admin dashboard device cards | N/A | ⬜ pending |
| 35-02-01 | 02 | 2 | HEALTH-04, HEALTH-05 | manual | Run the nickname/archive verification queries after each admin dashboard action | N/A | ⬜ pending |
| 35-02-02 | 02 | 2 | HEALTH-01, HEALTH-03, HEALTH-04, HEALTH-05 | static | `powershell -Command "Select-String -Path '.planning/REQUIREMENTS.md','.planning/STATE.md','.planning/phases/31-device-identity-foundation/31-VALIDATION.md','.planning/phases/32-multi-device-dashboard/32-VALIDATION.md','.planning/phases/35-multi-device-acceptance-verification/35-VALIDATION.md' -Pattern 'HEALTH-01','HEALTH-03','HEALTH-04','HEALTH-05','Phase 35','Approval:' | Measure-Object | Select-Object -ExpandProperty Count"` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all local automation needs for this phase.

No new test scaffolding is required before execution. The only non-local prerequisites are:

- one outlet with live Supabase access
- two physical kiosk devices for the same-outlet proof
- an admin account that can open the outlet dashboard

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Phase 34 rollout evidence is usable for outlet-level acceptance work | HEALTH-01, HEALTH-03 | Depends on prior live rollout records and production objects | 1. Review `34-VALIDATION.md` 2. If needed, run the minimal RPC existence query 3. Stop Phase 35 if the prerequisite remains unclear |
| UUID persists across logout and re-setup on the same physical device | HEALTH-01 | Requires real device storage continuity and real heartbeat timing | 1. Capture baseline `device_uuid` from `kiosk_devices` 2. Log out the same device 3. Re-run kiosk setup on that device 4. Confirm the next heartbeat uses the same UUID |
| Two devices on one outlet remain separate in DB and UI | HEALTH-03 | Needs two physical devices plus live dashboard rendering | 1. Sign in device A and B to the same outlet 2. Query active `kiosk_devices` rows for that outlet 3. Confirm two distinct UUIDs 4. Confirm the admin dashboard shows two separate cards |
| Nickname and archive flows persist against live Supabase data | HEALTH-04, HEALTH-05 | Requires live RPC side effects and a dashboard refresh | 1. Rename one device from the admin dashboard and confirm `nickname` updates in SQL 2. Archive the second device and confirm `is_active = false` plus dashboard disappearance |

---

## Operator Notes

### Prerequisite Check

- Review `.planning/phases/34-v6-supabase-rollout-evidence/34-VALIDATION.md`
- If a minimal live object check is needed before proceeding:

```sql
SELECT proname
FROM pg_proc
WHERE proname IN ('upsert_kiosk_heartbeat', 'set_device_nickname', 'archive_device')
ORDER BY proname;
```

### UUID Persistence

Baseline:

```sql
SELECT device_uuid, outlet_id, nickname, is_active, last_heartbeat_at, updated_at
FROM kiosk_devices
ORDER BY updated_at DESC NULLS LAST
LIMIT 10;
```

Post re-setup:

```sql
SELECT device_uuid, outlet_id, nickname, is_active, last_heartbeat_at, updated_at
FROM kiosk_devices
WHERE device_uuid = '<DEVICE_UUID_FROM_BASELINE>'
ORDER BY updated_at DESC NULLS LAST
LIMIT 5;
```

### Dual-Device Same-Outlet

```sql
SELECT device_uuid, outlet_id, nickname, battery_level, pending_sync_count, last_heartbeat_at, is_active
FROM kiosk_devices
WHERE outlet_id = '<TARGET_OUTLET_ID>'
  AND is_active = TRUE
ORDER BY last_heartbeat_at DESC NULLS LAST;
```

### Nickname and Archive

```sql
SELECT id, device_uuid, nickname, is_active, updated_at
FROM kiosk_devices
WHERE outlet_id = '<TARGET_OUTLET_ID>'
ORDER BY updated_at DESC NULLS LAST;
```

```sql
SELECT id, device_uuid, nickname, is_active, updated_at
FROM kiosk_devices
WHERE id = '<ARCHIVED_DEVICE_ID>';
```

---

## Evidence Log

### 35-01-02 UUID Persistence

- Target outlet ID: `<fill during execution>`
- Device A UUID baseline: `<fill during execution>`
- Baseline heartbeat timestamp: `<fill during execution>`
- Post re-setup heartbeat timestamp: `<fill during execution>`
- Result: `<approved / blocked>`
- Notes: `<fill during execution>`

### 35-01-03 Dual-Device Same-Outlet

- Target outlet ID: `<fill during execution>`
- Device A UUID or prefix: `<fill during execution>`
- Device B UUID or prefix: `<fill during execution>`
- Latest heartbeat timestamps: `<fill during execution>`
- Dashboard observation: `<fill during execution>`
- Result: `<approved / blocked>`

### 35-02-01 Nickname and Archive

- Renamed device ID or UUID: `<fill during execution>`
- Saved nickname: `<fill during execution>`
- Archived device ID: `<fill during execution>`
- Archive query result: `<fill during execution>`
- Dashboard after refresh: `<fill during execution>`
- Result: `<approved / blocked>`

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or explicit live checkpoint coverage
- [ ] Sampling continuity: no 3 consecutive tasks without static/test support
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s for local checks
- [ ] `nyquist_compliant: true` set in frontmatter after executed proof is recorded

**Approval:** pending
