# Phase 10: Sakit/Izin Direct Input — Research

**Researched:** 2026-03-05
**Status:** Complete
**Requirement:** REQ-M5-04

## Executive Summary

Phase 10 closes the gap for REQ-M5-04: Kepala Gerai can directly set sakit/izin status for employees without an approval workflow. The existing codebase already has a `SakitIzinDialog` (created during Phase 9 planning but incomplete) that handles CREATE via SQLite offline queue. This phase needs to:

1. **Fix the insert path** — current dialog inserts via SQLite offline queue → SyncService. For admin-initiated records, direct Supabase INSERT is more reliable and gives immediate visibility in Rekap Harian.
2. **Add edit/delete capability** — no edit or delete for sakit/izin records exists anywhere in the codebase.
3. **Add a sakit/izin history view** — admin needs to see existing sakit/izin records to edit/delete them.
4. **Verify Rekap Harian rendering** — Phase 1 already implemented sakit/izin badge rendering (`_DailySummary.status == sakit/izin` → badge UI). Need to confirm new direct-inserted records surface correctly.

## Existing Code Analysis

### SakitIzinDialog (lib/screens/admin/sakit_izin_dialog.dart)
- **CREATE works** — type selector (sakit/izin), date picker (7 days back, 30 days forward), notes field
- **Insert path**: `SqliteService.insertPendingLog()` → `SyncService.syncPendingLogs()` — goes through offline queue
- **Problem**: Uses `ADMIN_INPUT` as device_id, inserts via SQLite queue which may not sync immediately
- **Schedule integration**: Updates `ScheduleSQLiteService` if a schedule entry exists for that date
- **UI is polished** — uses AppColors, AppToast, proper error handling

### Admin Employees Screen (lib/screens/admin/admin_employees_screen.dart)
- `_showSakitIzinDialog(employee)` already wired to employee card popup menu (`sakit_izin` value)
- Dialog opens with employee + outletId + outletName
- On success (returns `true`), calls `_loadData()` to refresh

### Attendance Logs Table (Supabase)
- Columns: `id`, `employee_id`, `scan_outlet_id`, `type`, `lat`, `lng`, `device_id`, `scanned_at`, `synced_at`, `local_id`, `created_at`, `is_backup`, `notes`
- `type` CHECK constraint: `masuk`, `break`, `pulang`, `kembali`, `sakit`, `izin` — sakit/izin already supported
- RLS: `admin_all_logs` policy with ALL permissions (admin can SELECT, INSERT, UPDATE, DELETE)
- `auth_all_attendance_logs` policy with ALL on true — authenticated users have full access
- 242 rows currently in production

### Rekap Harian Rendering (Phase 1 — already done)
- `_DailySummary` has status field: `normal`, `sakit`, `izin`, `tidakHadir`, `belumPulang`
- Detection: if only sakit/izin scan exists for a day → status = sakit/izin → badge UI rendered
- Badge renders: red "🤒 Sakit" or blue "📋 Izin" with notes below
- Decision #8: sakit/izin badge only when `!hasMasukScan` — mixed days show normal 4-cell view

### Sync Service (lib/services/sync_service.dart)
- Uses `SupabaseClientFactory.kiosk` client — might have different permissions than admin client
- Deduplication via `local_id` (PostgrestException code 23505)

## Gap Analysis

| Requirement | Status | Gap |
|-------------|--------|-----|
| Set sakit/izin < 3 tap | ✅ Exists | Dialog accessible from employee card menu (2 taps to open) |
| Catatan opsional | ✅ Exists | Notes field with validation (required for izin, optional for sakit) |
| Langsung muncul di Rekap Harian | ⚠️ Partial | Insert goes via SQLite queue → may not appear immediately. Fix: direct Supabase insert |
| Set untuk tanggal lampau | ✅ Exists | Date picker allows 7 days back (could extend to 30 days for more flexibility) |
| Edit/hapus jika salah | ❌ Missing | No edit or delete capability exists anywhere |

## Implementation Approach

### Plan 1: Fix Insert Path + Add Sakit/Izin History List
**Scope:**
1. Modify `SakitIzinDialog._submit()` to INSERT directly to Supabase via `SupabaseClientFactory.admin` instead of SQLite queue
2. Keep SQLite queue as fallback only if Supabase fails (offline scenario)
3. Create `SakitIzinListScreen` — shows sakit/izin records for a specific employee with date range filter
4. Add navigation from employee card to sakit/izin history

### Plan 2: Edit + Delete Sakit/Izin Records
**Scope:**
1. Add edit mode to `SakitIzinDialog` — pre-fill existing record values, UPDATE on submit
2. Add delete confirmation dialog with Supabase DELETE
3. Wire edit/delete actions from `SakitIzinListScreen` record tiles
4. Extend date picker range to 30 days back for backdated entries

## Technical Decisions

### Why Direct Supabase INSERT (not SQLite queue)?
- Admin panel always requires network (Supabase auth)
- SQLite queue is designed for kiosk offline-first flow
- Direct insert = immediate visibility in reports
- Simpler error handling (no sync delay)
- Uses `SupabaseClientFactory.admin` which has full RLS permissions

### Edit vs Delete Strategy
- **Edit**: UPDATE attendance_logs SET type, notes, scanned_at WHERE id = X
- **Delete**: DELETE FROM attendance_logs WHERE id = X AND type IN ('sakit', 'izin')
  - Safety: only allow delete of sakit/izin type records from this UI
  - Prevents accidental deletion of masuk/pulang scan records

### Date Handling for Backdated Entries
- `scanned_at` should be set to selected date at 08:00 UTC+8 (WITA, Indonesia Central Time)
- This ensures the record appears in the correct day bucket in Rekap Harian
- Current code uses `now().hour/minute` which is wrong for backdated entries — fix needed

### Sakit/Izin History View Design
- Accessible from employee card long-press or popup menu
- Shows list of sakit/izin records for that employee
- Filter by date range (default: last 30 days)
- Each record tile: date, type badge, notes, edit/delete actions
- Consistent with existing admin UI patterns (AppCard, AppToast, shimmer loading)

## Validation Architecture

### Dimension 1: Functional Correctness
- Direct Supabase INSERT creates valid attendance_log with correct type
- Edit updates correct record fields
- Delete removes only sakit/izin type records

### Dimension 2: Data Integrity
- scanned_at date correctly anchored for backdated entries
- No duplicate sakit/izin for same employee+date (check before insert)
- Delete restricted to sakit/izin types only

### Dimension 3: UI/UX Consistency
- Dialog reuses existing SakitIzinDialog patterns
- History list uses AppCard, shimmer, AppEmptyState
- Edit mode pre-fills all fields correctly

### Dimension 4: Error Handling
- Network failure → clear error message, no silent failures
- Duplicate date → user-friendly warning
- RLS permission issues → handled gracefully

## Files Modified (Estimated)

| File | Changes |
|------|---------|
| `lib/screens/admin/sakit_izin_dialog.dart` | Fix insert path to direct Supabase, add edit mode |
| `lib/screens/admin/admin_employees_screen.dart` | Add sakit/izin history navigation |
| `lib/screens/admin/sakit_izin_list_screen.dart` | NEW — sakit/izin history list |
| `lib/models/attendance_log.dart` | No changes needed (model already complete) |

## Risk Assessment

- **Low risk**: All changes are in admin UI layer, no kiosk flow impact
- **Low risk**: RLS policies already support admin ALL operations
- **Low risk**: attendance_logs schema already supports sakit/izin types
- **Medium risk**: Date anchoring for backdated entries must match Rekap Harian date bucketing logic (noon rule from Phase 1)

## RESEARCH COMPLETE
