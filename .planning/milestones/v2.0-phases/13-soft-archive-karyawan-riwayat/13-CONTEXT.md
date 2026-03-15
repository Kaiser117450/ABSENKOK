# Phase 13: Soft-Archive Karyawan + Riwayat - Context

**Gathered:** 2026-03-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Admin can archive (soft-delete) departing karyawan, preserving full attendance history. Archived employees are excluded from NFC scan, schedule assignment, and active employee list. Admin can view archived employees in a Riwayat Karyawan page and restore them. Archive confirmation shows impact (upcoming shifts affected).

</domain>

<decisions>
## Implementation Decisions

### Archive UX flow
- Default employee list shows **active karyawan only** (no change to current default behavior)
- **Tombol kecil "Arsip"** added to existing action button row (alongside Jadwal, Refresh, Belum Pulang) — opens Riwayat Karyawan page
- Arsip action is inside **_EmployeeSheet (edit form)**, NOT from PopupMenu — admin opens edit → sees "Arsipkan Karyawan" button at the bottom
- **Toggle isActive ("Karyawan Aktif") stays** as-is for temporary deactivation — "Arsipkan" is a separate destructive button below the toggle
- Two distinct actions: toggle isActive = temporary nonaktif (can still appear in lists), Arsipkan = move to archive (hidden from everything)
- Confirmation dialog before archive: shows count of upcoming scheduled shifts that will be removed

### Riwayat Karyawan page
- Simple list with AppCard per archived employee
- Each card shows: nama, outlet, tanggal diarsipkan (from archived_at)
- No attendance detail on this page — just the archived employee registry
- **"Pulihkan" button per item** to restore back to active list
- Not grouped by outlet — flat list, simple
- When restored: employee reappears in active list, can clock in via NFC again

### Archive data model
- Add `archived_at` timestamp column to employees table (nullable, additive migration)
- `archived_at` is **informational only** — shows when the employee was archived
- `is_active` remains the **sole filter** for all queries (NFC, schedule, dashboard, admin list)
- Archive action: set `is_active = false` + `archived_at = NOW()`
- Restore action: set `is_active = true` + `archived_at = NULL`
- ⚠️ Production database — additive migration only (ADD COLUMN nullable, never DROP/ALTER existing)

### Claude's Discretion
- Exact layout/styling of Arsipkan button in _EmployeeSheet (red/destructive style expected)
- Exact layout of Riwayat Karyawan page (standard AppCard pattern)
- Empty state for Riwayat page when no archived employees
- Whether to auto-delete future schedule_entries on archive or just let is_active filter handle it
- Loading/error states
- Animation/transition when navigating to Riwayat page

</decisions>

<specifics>
## Specific Ideas

- Tombol Arsip positioned in the same row as existing action buttons (Jadwal, Refresh, Belum Pulang) — consistent with current admin layout
- Archive is from inside the edit form, not a quick-action — this is intentional as it's a significant/destructive action requiring context
- Toggle isActive is for "sementara nonaktif" (can't scan but still in active list); Arsipkan is for "sudah tidak bekerja" (moved to history)

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AppCard` widget — for Riwayat Karyawan list items
- `AppEmptyState` widget — for empty archived list
- `_FilterChip2` in admin_employees_screen.dart — existing chip pattern (not needed here but reference)
- `_EmployeeSheet` — already has isActive toggle (SwitchListTile), add Arsipkan button below
- PopupMenu in employee cards — no changes needed (archive is via edit form)

### Established Patterns
- Employee query pattern: `.from('employees').select('*').eq('is_active', true)` — already used in kiosk, schedule, dashboard
- Admin employee list does NOT filter is_active (shows all) — this needs to change to show only active by default
- Confirmation dialog pattern: used in other destructive actions

### Integration Points
- `lib/models/employee.dart` — add `archivedAt` field (DateTime?)
- `lib/screens/admin/admin_employees_screen.dart` — add Arsip button to action row, filter active by default, add Arsipkan in _EmployeeSheet
- `lib/screens/admin/` — new `archived_employees_screen.dart` for Riwayat Karyawan
- `lib/services/employee_cache_service.dart` — already filters is_active, no change needed
- `lib/screens/admin/shift_scheduler_screen.dart` — already filters is_active, no change needed
- `lib/screens/kiosk/kiosk_idle_screen.dart` — NFC lookup already filters is_active, no change needed
- Supabase migration: `ALTER TABLE employees ADD COLUMN archived_at TIMESTAMPTZ DEFAULT NULL`

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 13-soft-archive-karyawan-riwayat*
*Context gathered: 2026-03-11*
