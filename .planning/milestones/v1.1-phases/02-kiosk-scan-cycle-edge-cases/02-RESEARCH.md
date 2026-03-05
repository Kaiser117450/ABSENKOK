# Phase 2: Kiosk Scan Cycle Edge Cases - Research

**Researched:** 2026-03-01
**Domain:** Flutter kiosk NFC scan flow, attendance state machine, admin dashboard widgets
**Confidence:** HIGH — based entirely on direct source code analysis

## Summary

Phase 2 addresses two bugs in the kiosk attendance cycle. BUG-004 concerns "lupa absen pulang" (forgot to clock out) — the kiosk resets to masuk at midnight regardless of open sessions, but the admin UI has no way to see or resolve open shifts, and Rekap Harian shows `--:--` for pulang instead of a meaningful "Belum Pulang" badge. BUG-005 concerns 24-hour outlets — the kiosk's scan logic in `kiosk_scan_screen.dart` uses `isSameDay` (calendar date match) to determine the last scan, which breaks for overnight shifts where the last masuk was yesterday.

The key insight is that the attendance type determination logic currently lives in `kiosk_scan_screen.dart` (`_loadLastAttendance` method), not in `kiosk_idle_screen.dart` as the phase description states. The fix must change the `isSameDay` guard to a 24-hour window check. A 24h safety net (force masuk if last masuk > 24h ago with no pulang) prevents infinite open sessions. Two admin features — a "Belum Pulang" badge in Rekap Harian and an "Open Shifts" widget on the dashboard — complete the feature set.

**Primary recommendation:** Change `_loadLastAttendance` in `kiosk_scan_screen.dart` from `isSameDay` check to a 24-hour window check, add `belumPulang` status to `DailySummaryStatus` enum in `admin_reports_screen.dart`, and add an Open Shifts section to `admin_dashboard_screen.dart` with inline manual-pulang capability.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| REQ-M1-04 | Lupa absen pulang handling: admin "Belum Pulang" badge + open shifts list + manual pulang by admin | DailySummaryStatus enum in admin_reports_screen.dart needs `belumPulang` variant; admin_dashboard_screen.dart needs open-shifts widget; Supabase INSERT for manual pulang |
| REQ-M1-05 | 24h outlet shift cycle: last-scan check must use 24h window not calendar day; 24h safety net for masuk override | `_loadLastAttendance` in kiosk_scan_screen.dart uses `isSameDay` — must become `now.difference(dt).inHours < 24`; also need `pulang` state to always force new masuk cycle |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| supabase_flutter | already in project | Attendance log queries and INSERT for manual pulang | Project standard; all DB access goes through SupabaseClientFactory |
| flutter_riverpod | already in project | State management; dashboard state for open-shifts list | Project standard |
| toastification | already in project | Feedback toasts on manual pulang success/failure | Project standard for toasts |

### No New Dependencies Required
All Phase 2 work is pure Dart/Flutter logic changes to existing files. No new packages needed.

---

## Architecture Patterns

### Where the Scan Cycle Logic Actually Lives

The phase description says "kiosk_idle_screen.dart" but the attendance type determination is actually in `kiosk_scan_screen.dart` (`_loadLastAttendance` method, lines 88-116). `kiosk_idle_screen.dart` handles employee lookup and routing — it navigates to `/kiosk/scan` after finding an employee. The scan type decision happens in the scan screen.

```
kiosk_idle_screen.dart   → NFC tap → finds employee → pushes /kiosk/scan
kiosk_scan_screen.dart   → _loadLastAttendance() → determines which buttons to show
                           → _buildSmartButtons() → renders action buttons based on _lastType
```

### Current Bug: isSameDay Check

**File:** `lib/screens/kiosk/kiosk_scan_screen.dart` lines 100-109

```dart
// CURRENT CODE (buggy for 24h outlets):
final isSameDay = dt.year == now.year &&
    dt.month == now.month &&
    dt.day == now.day;
if (isSameDay && mounted) {
  setState(() {
    _lastType = AttendanceTypeExt.fromString(data['type'] as String);
  });
}
// If NOT same calendar day → _lastType stays null → always shows Masuk button
// This breaks overnight shift: masuk 22:00 Day1 → scan at 06:00 Day2 → shows Masuk (wrong)
```

**Fix:** Replace `isSameDay` with a 24-hour window check:

```dart
// FIXED: 24h window check
final hoursDiff = now.difference(dt).inHours;
final within24h = hoursDiff < 24;
if (within24h && mounted) {
  setState(() {
    _lastType = AttendanceTypeExt.fromString(data['type'] as String);
  });
}
```

### 24h Safety Net: Force Masuk if Open Session > 24h

After applying the 24h window, add a second check: if the last log was `masuk` (or `break`/`kembali`) and it happened more than 24 hours ago, force `_lastType = null` so the screen shows Masuk regardless.

```dart
// After setting _lastType from 24h-window query:
if (_lastType != null && _lastType != AttendanceType.pulang) {
  // Check if this is a stale open session (> 24h)
  final hoursDiff = now.difference(dt).inHours;
  if (hoursDiff >= 24) {
    _lastType = null; // Force masuk — safety net
  }
}
```

Note: The 24h window query already filters to `< 24h`, so the safety net is implicitly applied by the window itself. If `hoursDiff >= 24`, the record won't be returned by a query filtered to the last 24 hours. The clean implementation is simply: use `>= .gte(scannedAfter24h)` in the Supabase query, or just use the `now.difference(dt).inHours < 24` check on the returned record.

### Recommended Pattern: Query with Time Constraint

```dart
Future<void> _loadLastAttendance(String employeeId) async {
  try {
    final cutoff = DateTime.now()
        .subtract(const Duration(hours: 24))
        .toUtc()
        .toIso8601String();

    final data = await SupabaseClientFactory.kiosk
        .from('attendance_logs')
        .select('type, scanned_at')
        .eq('employee_id', employeeId)
        .gte('scanned_at', cutoff)         // Only last 24 hours
        .order('scanned_at', ascending: false)
        .limit(1)
        .maybeSingle()
        .timeout(const Duration(seconds: 4));

    if (data != null && mounted) {
      setState(() {
        _lastType = AttendanceTypeExt.fromString(data['type'] as String);
        // NOTE: _lastType = pulang → next scan shows Masuk (correct)
        // NOTE: _lastType = null (no record in 24h) → shows Masuk (correct safety net)
      });
    }
    // If null → no recent log within 24h → _lastType stays null → Masuk shown
  } catch (_) {
    // Network/timeout → _lastType stays null → show all as fallback
  } finally {
    if (mounted) setState(() => _loadingLastType = false);
  }
}
```

This single change covers both the 24h shift cycle AND the safety net — if there is no log in the last 24 hours (including cases where masuk > 24h ago with no pulang), `_lastType = null` → Masuk button shown.

### Smart Buttons State Machine (Verified)

The `_buildSmartButtons()` switch already handles the correct next-state logic for all types:

| `_lastType` | Buttons Shown | Correct? |
|------------|---------------|----------|
| `null` | Masuk | Yes — new cycle |
| `masuk` | Istirahat + Pulang | Yes |
| `kembali` | Istirahat + Pulang | Yes |
| `breakTime` | Selesai Istirahat + Pulang | Yes |
| `pulang` | Masuk | Yes — new cycle |
| `sakit`/`izin` | Masuk | Yes |

No changes needed to `_buildSmartButtons()` itself — only `_loadLastAttendance` needs updating.

### REQ-M1-04 Task 3: "Belum Pulang" Badge in Rekap Harian

**File:** `lib/screens/admin/admin_reports_screen.dart`

Current `DailySummaryStatus` enum (line 768):
```dart
enum DailySummaryStatus { normal, sakit, izin }
```

Add `belumPulang`:
```dart
enum DailySummaryStatus { normal, sakit, izin, belumPulang }
```

In `_computeDailySummaries()` (around line 410), add detection after sakit/izin check:
```dart
// After existing sakit/izin detection:
// Detect "belum pulang" — has masuk but no pulang
if (dayStatus == DailySummaryStatus.normal && firstMasuk != null && lastPulang == null) {
  dayStatus = DailySummaryStatus.belumPulang;
}
```

In `_buildStatusBadge()` (line 966), add amber/orange badge for `belumPulang`:
```dart
// In _buildStatusBadge():
if (summary.status == DailySummaryStatus.belumPulang) {
  // Amber/orange badge: "⚠️ Belum Pulang"
}
```

In `_DailySummaryTile.build()` (line 1112-1115), add `belumPulang` to badge condition:
```dart
if (summary.status == DailySummaryStatus.sakit ||
    summary.status == DailySummaryStatus.izin ||
    summary.status == DailySummaryStatus.belumPulang)
  _buildStatusBadge()
else
  // 4-cell row (existing)
```

**IMPORTANT: Belum Pulang vs 4-cell rendering decision**

The "Belum Pulang" case still has a `firstMasuk` value. The requirement says show "Belum Pulang" instead of `--:--` on the pulang field. Two valid approaches:
1. Show it as a badge (replacing the 4-cell row entirely) — simpler to implement
2. Keep the 4-cell row but replace `--:--` with a "Belum Pulang" chip in the Pulang cell

Approach 1 is consistent with the existing sakit/izin pattern and the requirement text ("show masuk time with 'Belum Pulang'"). Looking at the requirement again: "show masuk time with 'Belum Pulang' instead of `--:--` on pulang field" — this suggests Approach 2 (keep cells, special-case pulang cell). However, Approach 1 (badge replacing the whole row) is what the existing code pattern supports and is simpler. The planner should choose based on which approach gives better UX. Research finding: both are feasible; recommend Approach 2 (keep masuk cell visible with "Belum Pulang" replacing pulang cell) for maximum information density.

### REQ-M1-04 Task 4: "Open Shifts" Widget on Admin Dashboard

**File:** `lib/screens/admin/admin_dashboard_screen.dart`

The dashboard currently has:
- `_buildHeroHeader()`
- `_buildStatGrid()` — 2×2 grid of today's counts
- `_buildQuickActions()` — horizontal chip row
- `_buildOutletFilter()`
- `_buildSectionHeader()`
- Log list (SliverList)

Add a new `_buildOpenShiftsWidget()` between `_buildStatGrid()` and `_buildQuickActions()`.

**Supabase Query for Open Shifts:**
```dart
// Fetch employees who have masuk yesterday but no pulang
// "Yesterday" = from start of yesterday to end of yesterday (local time)
final yesterday = DateTime.now().subtract(const Duration(days: 1));
final startOfYesterday = DateTime(yesterday.year, yesterday.month, yesterday.day)
    .toUtc().toIso8601String();
final endOfYesterday = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59)
    .toUtc().toIso8601String();

final data = await SupabaseClientFactory.admin
    .from('attendance_logs')
    .select('employee_id, employees(id, name, photo_url), scan_outlet_id')
    .eq('type', 'masuk')
    .gte('scanned_at', startOfYesterday)
    .lte('scanned_at', endOfYesterday);
```

Then filter in Dart: for each employee_id in the result, check if there is a `pulang` record after their masuk time (today or yesterday after masuk). Employees with masuk but no subsequent pulang = open shifts.

**Alternative approach (simpler):** Fetch all logs for yesterday + today, group by employee, detect open sessions in Dart.

**Data structure for open shifts:**
```dart
class _OpenShift {
  final String employeeId;
  final String employeeName;
  final String? photoUrl;
  final String masukTime; // ISO string
  final String outletId;
}
```

### REQ-M1-04 Task 5: Manual Pulang Record by Admin

**Insert pattern** (consistent with existing attendance log inserts in the app):
```dart
await SupabaseClientFactory.admin
    .from('attendance_logs')
    .insert({
      'employee_id': openShift.employeeId,
      'scan_outlet_id': openShift.outletId,
      'type': 'pulang',
      'scanned_at': DateTime.now().toUtc().toIso8601String(),
      // Or use yesterday's end time as a reasonable fallback
      'notes': 'Lupa absen pulang — diinput manual oleh admin',
      'is_backup': false,
    });
```

The `notes` field exists on `attendance_logs` (confirmed in `AttendanceLog` model, line 111). The admin can provide a custom note in a dialog before confirming.

**UI pattern:** Show a `showDialog` with a `TextField` for notes, then confirm. This matches the existing `_showOutletConfirmationDialog` pattern in kiosk_idle_screen.dart.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Manual pulang INSERT | Custom sync queue | Direct Supabase INSERT from SupabaseClientFactory.admin | Admin action, immediate write, no offline queue needed (admin is always online) |
| Open shifts detection | Complex SQL procedure | Client-side Dart filtering after Supabase fetch | Dataset is small (14 employees, daily); simpler than DB function |
| 24h time comparison | Custom datetime utils | `DateTime.now().difference(dt).inHours` | Standard Dart, no library needed |

---

## Common Pitfalls

### Pitfall 1: isSameDay Check is in kiosk_scan_screen.dart, Not kiosk_idle_screen.dart

**What goes wrong:** Phase description says "Refactor last-scan logic in `kiosk_idle_screen.dart`" but the actual last-scan query is in `kiosk_scan_screen.dart` (`_loadLastAttendance`). If the fix is applied to the wrong file, the bug persists.

**How to avoid:** Fix `_loadLastAttendance` in `kiosk_scan_screen.dart`. The idle screen handles employee lookup only; the scan screen handles attendance type determination.

### Pitfall 2: UTC vs Local Time in 24h Window

**What goes wrong:** The `scanned_at` field is stored in UTC. `DateTime.now()` returns local time. If the cutoff calculation mixes UTC and local, the 24h window will be offset by the timezone.

**How to avoid:** Always use `.toUtc()` for the cutoff sent to Supabase, and `DateTime.parse(data['scanned_at']).toLocal()` when displaying times. The existing code already does `DateTime.parse(data['scanned_at'] as String).toLocal()` correctly.

**Correct pattern:**
```dart
final cutoff = DateTime.now().subtract(const Duration(hours: 24)).toUtc().toIso8601String();
// Use in .gte('scanned_at', cutoff) query
```

### Pitfall 3: Open Shifts Query Must Account for Cross-Day (Midnight Shift)

**What goes wrong:** An employee on a 22:00–06:00 shift has masuk yesterday and pulang early this morning. A naive "masuk yesterday, no pulang yesterday" query would wrongly flag them as an open shift.

**How to avoid:** When checking for open shifts, look for masuk in the last 32 hours (not just yesterday), and check for pulang in the last 32 hours. If pulang exists after masuk, it is a closed shift — even if pulang is on a different calendar day.

**Query approach:**
```dart
final cutoff = DateTime.now()
    .subtract(const Duration(hours: 32))
    .toUtc().toIso8601String();

// Fetch all logs (masuk + pulang) within last 32h for each employee
// Then in Dart: find employees where most recent masuk has no subsequent pulang
```

### Pitfall 4: belumPulang Badge Should Not Fire on Today's Active Shift

**What goes wrong:** An employee who scanned masuk today but hasn't yet scanned pulang (they are currently working) would appear in Rekap Harian with a "Belum Pulang" badge if the report is run mid-day.

**How to avoid:** The `belumPulang` badge should only fire for past dates (not today's date). Add a date check in `_computeDailySummaries()`:

```dart
// Only apply belumPulang for past dates (not today)
final today = DateTime.now();
final isToday = groupDate.year == today.year &&
    groupDate.month == today.month &&
    groupDate.day == today.day;

if (!isToday && dayStatus == DailySummaryStatus.normal &&
    firstMasuk != null && lastPulang == null) {
  dayStatus = DailySummaryStatus.belumPulang;
}
```

### Pitfall 5: supabaseReady Guard for Open Shifts Fetch

**What goes wrong:** Like all Supabase calls in the project, the open shifts query must be guarded by `supabaseReady` or it crashes at startup.

**How to avoid:** Wrap any open-shifts fetch in `if (!supabaseReady) return;` per project convention.

### Pitfall 6: Manual Pulang Timestamp Choice

**What goes wrong:** When admin manually creates a pulang record, what `scanned_at` to use? Using `DateTime.now()` could record pulang today for yesterday's masuk, causing confusing entries.

**How to avoid:** Use the end of the masuk day as the pulang timestamp (e.g., 23:59 on the masuk date), or present the admin with a time picker. The simplest safe default: use `DateTime.now()` with a clearly visible note in the `notes` field. This is consistent with the requirement: "Allow admin to manually create pulang record with notes."

---

## Code Examples

### 1. Corrected `_loadLastAttendance` (kiosk_scan_screen.dart)

```dart
// Source: Phase 2 analysis of kiosk_scan_screen.dart lines 88-116
Future<void> _loadLastAttendance(String employeeId) async {
  try {
    final cutoff = DateTime.now()
        .subtract(const Duration(hours: 24))
        .toUtc()
        .toIso8601String();

    final data = await SupabaseClientFactory.kiosk
        .from('attendance_logs')
        .select('type, scanned_at')
        .eq('employee_id', employeeId)
        .gte('scanned_at', cutoff)          // 24h window replaces isSameDay
        .order('scanned_at', ascending: false)
        .limit(1)
        .maybeSingle()
        .timeout(const Duration(seconds: 4));

    if (data != null && mounted) {
      setState(() {
        _lastType = AttendanceTypeExt.fromString(data['type'] as String);
        // pulang → shows Masuk (new cycle)  ✓
        // masuk/break/kembali within 24h → shows correct next-step buttons  ✓
        // no record in 24h → _lastType = null → shows Masuk  ✓ (safety net)
      });
    }
  } catch (_) {
    // Network/timeout → _lastType stays null → show Masuk as safe fallback
  } finally {
    if (mounted) setState(() => _loadingLastType = false);
  }
}
```

### 2. belumPulang Detection in _computeDailySummaries (admin_reports_screen.dart)

```dart
// Source: Phase 2 analysis of admin_reports_screen.dart _computeDailySummaries
// Add after existing sakit/izin detection (around line 412):

final groupDate = DateTime.tryParse(datePart);
final today = DateTime.now();
final isToday = groupDate != null &&
    groupDate.year == today.year &&
    groupDate.month == today.month &&
    groupDate.day == today.day;

// belumPulang: has masuk but no pulang, and it is a past date
if (!isToday &&
    dayStatus == DailySummaryStatus.normal &&
    firstMasuk != null &&
    lastPulang == null) {
  dayStatus = DailySummaryStatus.belumPulang;
}
```

### 3. Open Shifts Query (admin_dashboard_screen.dart)

```dart
// Source: Phase 2 analysis — new method for AdminDashboardScreen
Future<void> _loadOpenShifts() async {
  if (!supabaseReady) return;
  try {
    // Last 32h to catch overnight shifts
    final cutoff = DateTime.now()
        .subtract(const Duration(hours: 32))
        .toUtc()
        .toIso8601String();

    final data = await SupabaseClientFactory.admin
        .from('attendance_logs')
        .select('employee_id, type, scanned_at, scan_outlet_id, employees(id, name, photo_url)')
        .gte('scanned_at', cutoff)
        .order('scanned_at', ascending: true);

    // Group by employee_id, find those with masuk but no subsequent pulang
    final Map<String, List<Map<String, dynamic>>> byEmployee = {};
    for (final row in (data as List)) {
      final empId = row['employee_id'] as String;
      byEmployee.putIfAbsent(empId, () => []).add(row as Map<String, dynamic>);
    }

    final openShifts = <_OpenShift>[];
    byEmployee.forEach((empId, logs) {
      // Sort ascending by time
      logs.sort((a, b) => (a['scanned_at'] as String)
          .compareTo(b['scanned_at'] as String));
      // Find last masuk
      Map<String, dynamic>? lastMasuk;
      bool hasPulangAfterMasuk = false;
      for (final log in logs) {
        if (log['type'] == 'masuk') {
          lastMasuk = log;
          hasPulangAfterMasuk = false;
        } else if (log['type'] == 'pulang' && lastMasuk != null) {
          hasPulangAfterMasuk = true;
        }
      }
      if (lastMasuk != null && !hasPulangAfterMasuk) {
        final emp = lastMasuk['employees'] as Map<String, dynamic>?;
        openShifts.add(_OpenShift(
          employeeId: empId,
          employeeName: emp?['name'] as String? ?? '-',
          photoUrl: emp?['photo_url'] as String?,
          masukTime: lastMasuk['scanned_at'] as String,
          outletId: lastMasuk['scan_outlet_id'] as String,
        ));
      }
    });

    if (mounted) setState(() => _openShifts = openShifts);
  } catch (e) {
    debugPrint('[OpenShifts] Error: $e');
  }
}
```

### 4. Manual Pulang INSERT (admin_dashboard_screen.dart)

```dart
// Source: Phase 2 analysis — consistent with existing attendance_logs inserts
Future<void> _manualPulang(_OpenShift shift, String notes) async {
  try {
    await SupabaseClientFactory.admin
        .from('attendance_logs')
        .insert({
          'employee_id': shift.employeeId,
          'scan_outlet_id': shift.outletId,
          'type': 'pulang',
          'scanned_at': DateTime.now().toUtc().toIso8601String(),
          'notes': notes.isNotEmpty
              ? notes
              : 'Lupa absen pulang — diinput manual oleh admin',
          'is_backup': false,
        });
    // Refresh open shifts list
    await _loadOpenShifts();
  } catch (e) {
    // Show error toast
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `isSameDay` calendar check | 24h window `.gte(cutoff)` query | Overnight shifts handled correctly |
| No "Belum Pulang" state | `DailySummaryStatus.belumPulang` variant | Admin can distinguish open sessions from absent |
| No open shifts visibility | `_openShifts` list widget on dashboard | Admin sees open shifts proactively |

---

## Open Questions

1. **Belum Pulang tile rendering: badge vs 4-cell with special pulang cell**
   - What we know: Requirement says "show masuk time with Belum Pulang instead of --:--" suggesting the masuk time should remain visible
   - What's unclear: Whether the 4-cell row should be kept (with Pulang cell replaced) or whether a badge row replacing everything is acceptable
   - Recommendation: Keep 4-cell row, replace pulang cell content with an amber "Belum Pulang" chip when `dayStatus == belumPulang`. This preserves the masuk time and work context.

2. **Manual pulang timestamp: now() vs yesterday 23:59**
   - What we know: Using `DateTime.now()` records pulang as today's date for yesterday's masuk
   - What's unclear: Whether a time picker is worth the added UX complexity
   - Recommendation: Default to `DateTime.now()` (simple, audit-traceable via notes), with the notes field clearly stating it was manually entered. Admin can see the masuk time in the open shifts widget to know the context.

3. **Open shifts query scope: yesterday only vs last 32h**
   - What we know: The requirement says "employees who clocked in but not out yesterday"
   - What's unclear: Whether shifts from 2+ days ago should also appear
   - Recommendation: Use 32h window (covers overnight shifts from yesterday evening). Shift from 2+ days ago are edge cases — the 24h safety net on the kiosk side handles them by forcing a new masuk cycle.

---

## Files to Modify

| File | Change | Scope |
|------|--------|-------|
| `lib/screens/kiosk/kiosk_scan_screen.dart` | Replace `isSameDay` with 24h window in `_loadLastAttendance` | 15 lines |
| `lib/screens/admin/admin_reports_screen.dart` | Add `belumPulang` to `DailySummaryStatus` enum + detection logic + tile rendering | ~40 lines |
| `lib/screens/admin/admin_dashboard_screen.dart` | Add `_openShifts` list, `_loadOpenShifts()`, `_manualPulang()`, `_buildOpenShiftsWidget()` | ~120 lines |

No new files required. No database schema changes required. No new packages required.

---

## Validation Architecture

> Skipped — no `.planning/config.json` found with `workflow.nyquist_validation` setting. No existing test infrastructure detected in project (no `test/` directory with test files beyond Flutter's default `widget_test.dart`).

---

## Sources

### Primary (HIGH confidence)
- Direct analysis of `lib/screens/kiosk/kiosk_scan_screen.dart` (lines 88-116, 432-511) — actual scan logic
- Direct analysis of `lib/screens/admin/admin_reports_screen.dart` (lines 766-794, 960-1158) — DailySummaryStatus enum and tile rendering
- Direct analysis of `lib/screens/admin/admin_dashboard_screen.dart` (lines 106-158) — _loadLogs pattern to replicate for open shifts
- Direct analysis of `lib/models/attendance_log.dart` — AttendanceType enum and notes field confirmed
- `.planning/REQUIREMENTS.md` — REQ-M1-04 and REQ-M1-05 acceptance criteria
- `.planning/STATE.md` — confirmed Phase 1 complete, active bugs BUG-004 and BUG-005
- `CLAUDE.md` — architecture rules (supabaseReady guard, SharedPreferences, no Kotlin upgrade)

### Secondary (MEDIUM confidence)
- `.planning/codebase/ARCHITECTURE.md` — confirmed service layer patterns and data flow

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; existing patterns confirmed by source code
- Architecture: HIGH — all files read directly; exact line numbers confirmed
- Pitfalls: HIGH — based on code analysis of actual bugs (isSameDay, UTC/local, today vs past date)

**Research date:** 2026-03-01
**Valid until:** 2026-04-01 (stable codebase, no fast-moving dependencies)
