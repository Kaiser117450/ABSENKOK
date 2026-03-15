# Phase 8: Schedule System Fix + Supabase Integration - Research

**Researched:** 2026-03-02
**Domain:** Flutter schedule CRUD with Supabase persistence + offline SQLite cache
**Confidence:** HIGH

## Summary

The schedule system already has substantial infrastructure in place: Dart models (`ShiftSlot`, `ShiftTemplate`, `ScheduleEntry`, `OutletSchedule`), a SQLite offline service (`ScheduleSQLiteService`), a schedule generator (`ScheduleGenerator`), and a full screen UI (`ShiftSchedulerScreen`). The Supabase tables (`schedules`, `schedule_entries`, `shift_templates`) exist with correct schema, RLS policies, and foreign keys -- but have **0 rows** because the save flow has bugs and the load flow prioritizes SQLite over Supabase.

The existing `_saveSchedule()` method in `shift_scheduler_screen.dart` already attempts Supabase writes (lines 508-596) with a soft-delete + insert strategy. However, there are critical issues: (1) the `schedules` table has a `template_id` FK to `shift_templates` but the current code does not send `template_id`, (2) the `_generateAutoSchedule()` method only saves to SQLite (line 420) and never calls Supabase, (3) the load flow checks SQLite first and only falls back to Supabase if SQLite is empty (lines 108-115), meaning stale local data always wins over fresh cloud data. The week-view grid UI already exists and is functional (synchronized scroll, color-coded chips) but lacks bulk assign capability.

**Primary recommendation:** Fix the data flow (Supabase-first read, dual-write on save, `template_id` FK), add bulk assign UI, and wire `ScheduleSQLiteService` as a write-through cache -- not a primary data source.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `supabase_flutter` | already in pubspec | Supabase client for schedules CRUD | Project standard -- all DB ops use this |
| `sqflite` | already in pubspec | Offline SQLite cache for schedules | Project standard -- `ScheduleSQLiteService` exists |
| `flutter_riverpod` | already in pubspec | State management | Project standard |
| `intl` | already in pubspec | Date formatting in grid UI | Already used in scheduler |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `connectivity_plus` | already in pubspec | Check network before sync | Used by existing `SyncService` pattern |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual Supabase CRUD | `supabase_flutter` realtime subscription | Overkill -- schedule changes are infrequent, pull-on-open is sufficient |
| SQLite-first with sync | Supabase-first with SQLite cache | Supabase-first is correct for multi-device visibility (the core requirement) |

**Installation:** No new dependencies needed. Everything is already in `pubspec.yaml`.

## Architecture Patterns

### Current File Structure (Relevant)
```
lib/
  models/
    shift_schedule.dart        # ShiftSlot, ShiftTemplate, ScheduleEntry, OutletSchedule
  screens/admin/
    shift_scheduler_screen.dart # Full scheduler UI (1005 lines)
  services/
    schedule_sqlite_service.dart # SQLite CRUD for schedules
    schedule_generator.dart      # Auto-generation algorithm
    sync_service.dart            # Attendance log sync (pattern reference)
```

### Pattern 1: Supabase-First Read with SQLite Fallback
**What:** On screen open, fetch from Supabase. If offline or error, fall back to SQLite cache.
**When to use:** Multi-device visibility is required (core UAT requirement).
**Current bug:** Code does SQLite-first (line 109), only hitting Supabase if SQLite returns null. This means device A saves a schedule, device B never sees it because device B has its own stale SQLite data.

**Fix pattern:**
```dart
// CORRECT: Supabase first, SQLite fallback
Future<void> _loadData() async {
  OutletSchedule? schedule;
  try {
    schedule = await _loadScheduleFromSupabase(outletId, start, end, employees);
    if (schedule != null) {
      // Cache to SQLite for offline use
      await ScheduleSQLiteService.saveSchedule(schedule);
    }
  } catch (e) {
    debugPrint('Supabase load failed, falling back to SQLite: $e');
  }
  schedule ??= await ScheduleSQLiteService.getSchedule(outletId, start, end);
  // ... use schedule
}
```

### Pattern 2: Soft-Delete + Insert for Schedule Upsert
**What:** The existing `_saveSchedule()` uses a pseudo-atomic pattern: insert new schedule row, bulk insert entries, then soft-delete old schedule. This is correct for Supabase (no true transactions via PostgREST).
**Current implementation:** Lines 516-568 of `shift_scheduler_screen.dart` already implement this.
**Bug:** Missing `template_id` in the insert (Supabase `schedules` table has `template_id` FK to `shift_templates`).

### Pattern 3: Write-Through Cache
**What:** Every Supabase write also writes to SQLite. SQLite is never the sole write target.
**Current bug:** `_generateAutoSchedule()` (line 420) only calls `ScheduleSQLiteService.saveSchedule()` -- never writes to Supabase.

### Anti-Patterns to Avoid
- **SQLite-as-primary for shared data:** SQLite is device-local. Schedule must be visible across devices, so Supabase is the source of truth.
- **Generating schedule IDs client-side for Supabase:** The `schedules` table uses `uuid_generate_v4()` as default. Let Supabase generate IDs via `.insert().select('id').single()` pattern (already done on line 533).
- **Ignoring `template_id` FK:** The `schedules.template_id` column references `shift_templates.id`. Current code skips this, which works only because the column is nullable. But for data integrity, it should be populated.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Schedule ID generation | Client-side UUID | Supabase `uuid_generate_v4()` default | Consistency, no collision risk |
| Offline detection | Custom ping | `connectivity_plus` (already used by `SyncService`) | Reliable, cross-platform |
| Bulk insert | Loop of individual inserts | Single `.insert(List<Map>)` call | One HTTP round-trip (already done on line 558) |
| Week navigation | Manual date math | Existing `_getStartOfWeek()` + `Duration(days: 7)` | Already implemented correctly |

**Key insight:** The existing code is ~80% correct. The issues are data flow direction (SQLite-first vs Supabase-first) and missing FK population, not missing infrastructure.

## Common Pitfalls

### Pitfall 1: SQLite Date Format Mismatch with Supabase
**What goes wrong:** SQLite stores full ISO8601 timestamps (`2026-03-02T00:00:00.000`), Supabase `date` columns store `2026-03-02`. The existing `_loadScheduleFromSupabase` already handles this correctly with `.split('T')[0]` on line 145, but the SQLite service stores full ISO8601 (line 78 of `schedule_sqlite_service.dart`).
**Why it happens:** SQLite `getSchedule` compares full ISO strings, so `2026-03-02T00:00:00.000` != `2026-03-02T00:00:00.000Z` (timezone suffix).
**How to avoid:** Normalize dates to `yyyy-MM-dd` strings for both SQLite storage and Supabase queries. The current SQLite service stores `startDate.toIso8601String()` which may not match on reload.
**Warning signs:** Schedule loads from Supabase but not from SQLite cache (or vice versa).

### Pitfall 2: template_id FK Violation
**What goes wrong:** The `schedules` table has `template_id` FK to `shift_templates`. Current code does not send `template_id` in the insert (line 533). This works because the column is nullable, but is data incomplete.
**Why it happens:** The Flutter model uses a local `ShiftTemplate` object with hardcoded IDs like `template_pagi_siang_sore`, not Supabase UUIDs.
**How to avoid:** Either (a) look up the matching `shift_templates` row by outlet_id and populate `template_id`, or (b) leave it null and accept the denormalization (the `shift_slot` JSONB on each entry is self-contained).
**Recommendation:** Option (b) is pragmatic -- the JSONB in `schedule_entries.shift_slot` already contains all shift info. Populating `template_id` is nice-to-have but not blocking.

### Pitfall 3: Stale SQLite Cache Overriding Cloud Data
**What goes wrong:** Device A creates schedule, device B opens scheduler but sees its own old SQLite data.
**Why it happens:** Current code (line 109) checks SQLite first.
**How to avoid:** Always try Supabase first. Only fall back to SQLite on network error.
**Warning signs:** UAT "open on device B, data not same" fails.

### Pitfall 4: Auto-Generate Not Persisting to Supabase
**What goes wrong:** User taps auto-generate, sees schedule in UI, but it only saves to SQLite (line 420). Other devices never see it.
**Why it happens:** `_generateAutoSchedule()` calls `ScheduleSQLiteService.saveSchedule()` but not `_saveSchedule()`.
**How to avoid:** After auto-generate, either auto-save to Supabase or clearly indicate "unsaved draft" state requiring explicit save.

### Pitfall 5: Bulk Insert Size Limits
**What goes wrong:** For 14 employees x 7 days = 98 entries, a single bulk insert is fine. But if the system grows to 50+ employees or monthly schedules (30 days), the payload could be large.
**Why it happens:** PostgREST has default body size limits.
**How to avoid:** For this restaurant chain (4 outlets, ~14 employees each), 98 entries per week is well within limits. No chunking needed now.

## Code Examples

### Supabase Schedule Save (Fixed)
```dart
// Source: Existing shift_scheduler_screen.dart lines 516-568, with fixes annotated
Future<void> _saveSchedule() async {
  if (_currentSchedule == null) return;
  setState(() => _isLoading = true);
  try {
    final startDateStr = _currentSchedule!.startDate.toIso8601String().split('T')[0];
    final endDateStr = _currentSchedule!.endDate.toIso8601String().split('T')[0];

    // 1. Check for existing active schedule in this period
    final existing = await SupabaseClientFactory.admin
        .from('schedules').select('id')
        .eq('outlet_id', _currentSchedule!.outletId)
        .eq('start_date', startDateStr)
        .eq('end_date', endDateStr)
        .eq('is_active', true)
        .maybeSingle();
    final existingId = existing?['id'] as String?;

    // 2. Insert new schedule (let Supabase generate UUID)
    final result = await SupabaseClientFactory.admin.from('schedules').insert({
      'outlet_id': _currentSchedule!.outletId,
      'start_date': startDateStr,
      'end_date': endDateStr,
      'is_active': true,
      // template_id: nullable, not required since shift_slot JSONB is self-contained
    }).select('id').single();
    final newScheduleId = result['id'];

    // 3. Bulk insert entries
    final entriesData = _currentSchedule!.entries.map((entry) => {
      'schedule_id': newScheduleId,
      'date': entry.date.toIso8601String().split('T')[0],
      'employee_id': entry.employeeId,
      'custom_name': entry.customName,
      'display_name': entry.displayName,
      'is_custom_name': entry.isCustomName,
      'shift_slot': entry.shift.toJson(),
      'is_day_off': entry.isDayOff,
      'notes': entry.notes,
    }).toList();
    if (entriesData.isNotEmpty) {
      await SupabaseClientFactory.admin.from('schedule_entries').insert(entriesData);
    }

    // 4. Soft-delete old schedule
    if (existingId != null) {
      await SupabaseClientFactory.admin.from('schedules')
          .update({'is_active': false}).eq('id', existingId);
    }

    // 5. Also cache to SQLite for offline
    await ScheduleSQLiteService.saveSchedule(_currentSchedule!);
  } catch (e) { /* error handling */ }
}
```

### Supabase-First Load Pattern
```dart
// Source: Modified from existing _loadData pattern
Future<OutletSchedule?> _loadScheduleSmartFetch(
  String outletId, DateTime start, DateTime end, List<Employee> employees
) async {
  // Try Supabase first
  try {
    final schedule = await _loadScheduleFromSupabase(outletId, start, end, employees);
    if (schedule != null) {
      // Write-through: cache to SQLite
      await ScheduleSQLiteService.saveSchedule(schedule);
      return schedule;
    }
  } catch (e) {
    debugPrint('Supabase fetch failed: $e');
  }
  // Fallback to SQLite
  return await ScheduleSQLiteService.getSchedule(outletId, start, end);
}
```

### Bulk Assign UI Pattern
```dart
// Bulk assign: select employees, pick shift, apply to all days
void _bulkAssign(List<Employee> selectedEmployees, ShiftSlot shift) {
  final days = List.generate(7, (i) => _startDate.add(Duration(days: i)));
  setState(() {
    for (final emp in selectedEmployees) {
      for (final day in days) {
        if (_getSakitIzin(emp.id, day) != null) continue; // skip sakit/izin
        _currentSchedule!.entries.removeWhere((e) =>
          e.employeeId == emp.id &&
          e.date.year == day.year && e.date.month == day.month && e.date.day == day.day);
        _currentSchedule!.entries.add(ScheduleEntry.fromEmployee(
          id: '${DateTime.now().millisecondsSinceEpoch}_${emp.id}_${day.day}',
          date: day, employee: emp, shift: shift,
        ));
      }
    }
  });
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SQLite-only schedule storage | Supabase + SQLite write-through | Phase 8 (this phase) | Multi-device schedule visibility |
| Individual cell assignment only | Bulk assign (select employees + shift) | Phase 8 (this phase) | 2-click bulk operations per UAT |

**Deprecated/outdated:**
- `ScheduleGenerator` advanced algorithm: Currently unused by the screen. The simpler `_generateAutoSchedule()` in the screen does its own round-robin. The generator is available but not wired.

## Supabase Schema Analysis

### `schedules` Table (0 rows)
| Column | Type | Nullable | Notes |
|--------|------|----------|-------|
| `id` | uuid | PK, auto | `uuid_generate_v4()` |
| `outlet_id` | uuid | nullable | FK to `outlets.id` |
| `start_date` | date | NOT NULL | Week start (Monday) |
| `end_date` | date | NOT NULL | Week end (Sunday) |
| `template_id` | uuid | nullable | FK to `shift_templates.id` -- currently NOT populated by app |
| `created_by` | uuid | nullable | FK to `auth.users.id` -- currently NOT populated by app |
| `created_at` | timestamptz | nullable | Default `now()` |
| `updated_at` | timestamptz | nullable | Default `now()` |
| `synced_at` | timestamptz | nullable | Not used by current code |
| `is_active` | boolean | nullable | Default `true`, used for soft-delete |

### `schedule_entries` Table (0 rows)
| Column | Type | Nullable | Notes |
|--------|------|----------|-------|
| `id` | uuid | PK, auto | `uuid_generate_v4()` |
| `schedule_id` | uuid | nullable | FK to `schedules.id` |
| `date` | date | NOT NULL | Assignment date |
| `employee_id` | uuid | nullable | FK to `employees.id` |
| `custom_name` | text | nullable | For "OPEN" slots |
| `display_name` | text | NOT NULL | Employee name or custom |
| `is_custom_name` | boolean | nullable | Default `false` |
| `shift_slot` | jsonb | NOT NULL | `{name, start_hour, start_minute, end_hour, end_minute, color}` |
| `is_day_off` | boolean | nullable | Default `false` |
| `notes` | text | nullable | |
| `created_at` | timestamptz | nullable | Default `now()` |

### `shift_templates` Table (3 rows)
Pre-populated with "Pagi & Sore" for 3 outlets. Contains `slots` JSONB array.

### RLS Policies
- `schedules`: `Enable all for authenticated` -- permissive ALL for authenticated users. **Sufficient for admin use.**
- `schedule_entries`: `Enable all for authenticated` -- same pattern. **Sufficient.**
- `shift_templates`: SELECT-only for authenticated, scoped by outlet or admin role.

### Missing Columns (Not Blocking)
- `schedule_entries` does not have a `status` column (sakit/izin/libur). The Flutter model has `ScheduleStatus` but it is NOT persisted to Supabase. The `is_day_off` boolean + `shift_slot.name = "Libur"` covers the main case. Sakit/izin are loaded separately from `attendance_logs`, not stored in schedule entries.

## Identified Bugs in Current Code

### BUG-S1: SQLite-First Load Order (CRITICAL for multi-device)
- **File:** `shift_scheduler_screen.dart` line 109
- **Issue:** Checks SQLite first, only falls to Supabase if null
- **Fix:** Reverse order -- Supabase first, SQLite fallback

### BUG-S2: Auto-Generate Saves to SQLite Only
- **File:** `shift_scheduler_screen.dart` line 420
- **Issue:** `_generateAutoSchedule()` calls `ScheduleSQLiteService.saveSchedule()` but not `_saveSchedule()`
- **Fix:** Either call `_saveSchedule()` after generate, or mark as unsaved draft

### BUG-S3: Missing `template_id` in Supabase Insert
- **File:** `shift_scheduler_screen.dart` line 533
- **Issue:** `schedules` insert does not include `template_id`
- **Impact:** Low -- column is nullable, shift data is self-contained in entries JSONB
- **Fix:** Optional -- look up `shift_templates` by outlet_id and populate, or leave null

### BUG-S4: SQLite Date Normalization
- **File:** `schedule_sqlite_service.dart` line 78-79
- **Issue:** Stores `startDate.toIso8601String()` which includes time component, but queries compare exact strings
- **Impact:** Could cause cache misses if DateTime objects have different time components
- **Fix:** Normalize to `yyyy-MM-dd` format for date-only columns

## Open Questions

1. **Should `_generateAutoSchedule()` auto-save to Supabase or remain a local draft?**
   - What we know: Current behavior saves to SQLite only. UAT says "buat jadwal -> tersimpan di Supabase".
   - Recommendation: Auto-generate should remain a draft (local only). User must explicitly tap Save to persist to Supabase. Add visual "unsaved changes" indicator.

2. **Should we populate `template_id` and `created_by` on `schedules` insert?**
   - What we know: Both columns are nullable. `template_id` FK exists but app uses local ShiftTemplate objects. `created_by` FK references `auth.users` but kiosk mode may not have auth user.
   - Recommendation: Populate `template_id` if a matching `shift_templates` row exists for the outlet. Leave `created_by` null for now (admin auth integration is a separate concern).

3. **Bulk assign UX: checkbox per employee or "select all" toggle?**
   - What we know: UAT says "assign bulk untuk 5 karyawan dalam 2 klik".
   - Recommendation: "Select All" checkbox at top of employee column + individual toggles. Then a floating action button to pick shift type. Two clicks: Select All + Pick Shift.

## Sources

### Primary (HIGH confidence)
- Supabase project `tmapxdftdhxovthgbhww` -- live schema inspection via `list_tables` and `execute_sql`
- Source code: `shift_scheduler_screen.dart` (1005 lines), `schedule_sqlite_service.dart` (244 lines), `shift_schedule.dart` (418 lines), `schedule_generator.dart` (243 lines)
- RLS policies verified via `pg_policies` query

### Secondary (MEDIUM confidence)
- `shift_templates` table has 3 rows with "Pagi & Sore" template for 3 outlets (verified via SQL)
- `schedules` and `schedule_entries` both have 0 rows (confirmed the bug is real)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies needed, all libraries already in project
- Architecture: HIGH -- existing code is 80% correct, bugs are well-identified from source analysis
- Pitfalls: HIGH -- all pitfalls identified from direct code reading and live DB inspection

**Research date:** 2026-03-02
**Valid until:** 2026-04-02 (stable -- no fast-moving dependencies)
