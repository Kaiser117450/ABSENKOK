# Phase 1: Rekap Harian Bug Fixes - Research

**Researched:** 2026-02-28
**Domain:** Flutter/Dart — data computation logic, Supabase query design, widget rendering
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| REQ-M1-01 | Fix Rekap Harian: sakit/izin days must show a status badge, NOT 4 time cells | `_DailySummary` needs a `status` field; `_DailySummaryTile` needs a conditional rendering branch |
| REQ-M1-02 | Fix Rekap Harian: summaries must use a full (non-paginated) data fetch — not the Per-Scan 50-record page | A separate `_loadDailySummaryData()` fetch method with no `.range()` call; `_DailySummary` list stored separately from `_rows` |
| REQ-M1-03 | Fix cross-day shift grouping: masuk at 22:00 Day1 + pulang at 06:00 Day2 → one session anchored to Day1 | "Shift anchor" algorithm in `_computeDailySummaries()` — re-attach pulang records that land before noon of the day after masuk |
</phase_requirements>

---

## Summary

Phase 1 fixes three pure Dart logic/UI bugs inside a single file: `lib/screens/admin/admin_reports_screen.dart`. No database schema changes, no new packages, no platform-channel work. All three bugs stem from the same root: the `_computeDailySummaries()` function was designed only for the simple same-day, masuk-then-pulang case.

BUG-001 is a rendering bug. `_DailySummary` carries no information about whether a day is a sakit/izin day; `_DailySummaryTile` therefore always renders the 4 time cells regardless. The fix is surgical: add a `DailySummaryStatus` enum to `_DailySummary`, populate it during computation, and add a conditional branch in `_DailySummaryTile.build()` that renders a badge row instead of the 4-cell row when status is `sakit` or `izin`.

BUG-002 is a data-fetch scope bug. `_computeDailySummaries()` runs on `_rows`, which is the paginated Per-Scan list (50 records, newest-first). For date ranges wider than ~2 days with 14 employees this cuts off earlier records. The fix is a second, independent Supabase fetch triggered at the same time as the Per-Scan fetch, stored in a separate `_dailyRows` list, with no `.range()` limit. Per-Scan pagination is untouched.

BUG-003 is a grouping-key bug. The grouping key is derived from the local-timezone date of `scanned_at`. A pulang scan at 06:00 Oct 16 gets key `oct-16` while its masuk was `oct-15`. The fix applies the "noon rule": after initial grouping, scan the resulting groups for orphaned pulang records (no masuk in same group, time < 12:00), look up the prior-day group for the same employee, and re-attach those pulang records there.

**Primary recommendation:** Fix all three bugs in `admin_reports_screen.dart` only. No other files need modification.

---

## Standard Stack

### Core (already in project — no new installs)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `supabase_flutter` | ^2.8.4 | Supabase PostgREST query builder | Already in project; `.select()`, `.gte()`, `.lte()`, `.order()` — no `.range()` for full fetch |
| `flutter_riverpod` | ^2.6.1 | State management — `ConsumerStatefulWidget`, `setState` | Already in project; screen already uses it |
| `flutter` (Material) | SDK | `TabBar`, `TabBarView`, `Container`, `Row`, `Column`, widget tree | Standard Flutter UI |
| `intl` | ^0.19.0 | Already in project; could be used for date formatting, but screen currently uses inline formatting | Available if needed |

### No New Dependencies
This phase requires zero new packages. All fixes are pure Dart logic and Flutter widget changes within the existing file.

---

## Architecture Patterns

### Current Screen Structure

```
admin_reports_screen.dart
├── _AdminReportsScreenState          (ConsumerStatefulWidget state)
│   ├── _rows: List<_ReportRow>       ← Per-Scan data (paginated, 50 records)
│   ├── _loadReport()                 ← fetches with .range() — KEEP AS-IS
│   ├── _computeDailySummaries()      ← RUNS ON _rows ← THIS IS THE BUG-002 ROOT
│   └── _buildRekapHarian()           ← calls _computeDailySummaries()
│
├── _DailySummary                     ← data class — needs `status` field (BUG-001)
├── _DailySummaryTile                 ← widget — needs conditional rendering (BUG-001)
├── _ReportRow                        ← raw scan row (unchanged)
└── _InfoCell                         ← sub-widget for time cells (unchanged)
```

### Pattern 1: Separate Data Fetch for Rekap Harian (BUG-002 fix)

**What:** Add `_dailyRows: List<_ReportRow>` and `_loadingDaily: bool` state fields. Add `_loadDailySummaryData()` that fetches the FULL date range with no `.range()` limit. Call it alongside `_loadReport()` in the Tampilkan button handler.

**When to use:** Any time a computation tab needs a different data scope than the pagination tab.

**Implementation approach:**
```dart
// New state fields in _AdminReportsScreenState:
List<_ReportRow> _dailyRows = [];
bool _loadingDaily = false;

// New fetch method — NO .range(), fetches ALL records for date range:
Future<void> _loadDailySummaryData() async {
  setState(() => _loadingDaily = true);
  try {
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

    var query = SupabaseClientFactory.admin
        .from('attendance_logs')
        .select('*, employees(*), outlets(*)')
        .gte('scanned_at', start.toUtc().toIso8601String())
        .lte('scanned_at', end.toUtc().toIso8601String());

    if (_selectedOutletId != null) {
      query = query.eq('scan_outlet_id', _selectedOutletId!);
    }

    // NO .range() here — fetch everything
    final data = await query.order('scanned_at', ascending: true);

    if (mounted) {
      setState(() {
        _dailyRows = (data as List)
            .map((e) => _ReportRow.fromJson(e as Map<String, dynamic>))
            .toList();
        _loadingDaily = false;
      });
    }
  } catch (e) {
    if (mounted) setState(() => _loadingDaily = false);
  }
}
```

**Calling point:** In `_loadReport(reset: true)`, call `_loadDailySummaryData()` in parallel (both are `async`, both called without `await` in the same button handler, or use `Future.wait`).

**`_computeDailySummaries()` change:** Switch from reading `_rows` to reading `_dailyRows`.

### Pattern 2: Status Enum in `_DailySummary` (BUG-001 fix)

**What:** Add a `DailySummaryStatus` enum. Populate it in `_computeDailySummaries()`. Use it in `_DailySummaryTile` to choose the correct rendering path.

```dart
enum DailySummaryStatus { normal, sakit, izin }
```

**Detection logic in `_computeDailySummaries()`:**
```dart
// After collecting all rows for a (employee, date) group:
final hasMasuk = rows.any((r) => r.log.type == AttendanceType.masuk);
final hasSakit = rows.any((r) => r.log.type == AttendanceType.sakit);
final hasIzin  = rows.any((r) => r.log.type == AttendanceType.izin);

DailySummaryStatus status = DailySummaryStatus.normal;
if (!hasMasuk && hasSakit) status = DailySummaryStatus.sakit;
if (!hasMasuk && hasIzin)  status = DailySummaryStatus.izin;

// Also capture notes from the sakit/izin log:
String? statusNotes;
if (status != DailySummaryStatus.normal) {
  statusNotes = rows
      .firstWhere((r) =>
          r.log.type == AttendanceType.sakit ||
          r.log.type == AttendanceType.izin)
      .log.notes;
}
```

**`_DailySummary` additions:**
```dart
class _DailySummary {
  // ... existing fields ...
  final DailySummaryStatus status;   // NEW
  final String? statusNotes;         // NEW — from attendance_logs.notes
```

**`_DailySummaryTile.build()` conditional:**
```dart
// After the header + divider, before the 4-cell row:
if (summary.status == DailySummaryStatus.sakit ||
    summary.status == DailySummaryStatus.izin) {
  // Render badge row instead of 4 cells
  return _buildStatusBadge();
} else {
  // Existing 4-cell row
  return _buildTimeCells();
}
```

**Badge widget approach (inline in `_DailySummaryTile`):**
```dart
Widget _buildStatusBadge() {
  final isSakit = summary.status == DailySummaryStatus.sakit;
  final color = isSakit ? const Color(0xFFDC2626) : const Color(0xFF2563EB);
  final emoji = isSakit ? '🤒' : '📋';
  final label = isSakit ? 'Sakit' : 'Izin';

  return Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        if (summary.statusNotes != null && summary.statusNotes!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              summary.statusNotes!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    ),
  );
}
```

### Pattern 3: Cross-Day Shift Grouping — Noon Rule (BUG-003 fix)

**What:** After building the initial `(employeeId|YYYY-MM-DD) → rows` map, do a second pass that re-attaches orphaned pulang records.

**When to use:** Any time an employee's work shift can span midnight.

**Algorithm:**
```dart
// After initial grouping loop, before computing summaries:
// Second pass: re-attach orphaned pulang (before 12:00) to prior day's group.
final keysToRemove = <String>[];
final rowsToAdd = <String, List<_ReportRow>>{};

for (final entry in groups.entries) {
  final key = entry.key; // "empId|YYYY-MM-DD"
  final rows = entry.value;

  final employeeId = key.split('|')[0];
  final dateStr = key.split('|')[1];
  final groupDate = DateTime.tryParse(dateStr);
  if (groupDate == null) continue;

  // Check if this group has ONLY pulang (no masuk) and the pulang is before 12:00
  final hasMasuk = rows.any((r) => r.log.type == AttendanceType.masuk);
  if (!hasMasuk) {
    final orphanPulangs = rows.where((r) {
      final dt = DateTime.tryParse(r.log.scannedAt)?.toLocal();
      return dt != null &&
          r.log.type == AttendanceType.pulang &&
          dt.hour < 12;
    }).toList();

    if (orphanPulangs.isNotEmpty) {
      // Build the prior-day key
      final priorDate = groupDate.subtract(const Duration(days: 1));
      final priorKey =
          '$employeeId|${priorDate.year}-${priorDate.month.toString().padLeft(2, '0')}-${priorDate.day.toString().padLeft(2, '0')}';

      if (groups.containsKey(priorKey)) {
        // Re-attach pulang rows to prior day
        rowsToAdd.putIfAbsent(priorKey, () => []).addAll(orphanPulangs);

        // Remove them from current group
        final remaining = rows.where((r) => !orphanPulangs.contains(r)).toList();
        if (remaining.isEmpty) {
          keysToRemove.add(key);
        } else {
          groups[key] = remaining;
        }
      }
    }
  }
}

// Apply mutations
for (final k in keysToRemove) groups.remove(k);
for (final entry in rowsToAdd.entries) {
  groups[entry.key]!.addAll(entry.value);
  // Re-sort after adding
  groups[entry.key]!.sort((a, b) =>
      a.log.scannedAt.compareTo(b.log.scannedAt));
}
```

**Important edge case:** The noon threshold (< 12:00) ensures a legitimate daytime pulang (e.g., 09:00 as a separate short-shift) is NOT re-attached to the previous day. Only after-midnight early-morning pulang scans are affected.

**Second edge case:** If the prior-day group does NOT exist (employee had no masuk recorded that day, e.g., data gap), do NOT re-attach — leave the pulang orphaned rather than creating a phantom session.

### Pattern 4: Loading State for Rekap Harian Tab

Per REQ-M1-02 acceptance criteria, a loading indicator must be shown while the full data fetch is in progress.

**In `_buildRekapHarian()`:**
```dart
Widget _buildRekapHarian() {
  if (_loadingDaily) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
  final summaries = _computeDailySummaries();
  // ... existing code
}
```

### Anti-Patterns to Avoid

- **Modifying `_rows` for the daily summary fix:** `_rows` is the source of truth for Per-Scan tab and pagination. Never alter it to remove the `.range()` limit — that would break pagination.
- **Using `.range(0, 9999)` as a workaround:** This is fragile and still technically paginated. Use no `.range()` at all for the full fetch.
- **Mutating a Map while iterating it in the noon-rule algorithm:** Collect mutations in separate lists, apply after the loop. (Pattern 3 above already does this correctly.)
- **Checking `firstMasuk == null` to detect sakit/izin:** A day CAN have masuk + sakit recorded erroneously. The correct check per REQ-M1-01 is: `!hasMasuk && (hasSakit || hasIzin)`.
- **Storing notes in `_DailySummary.workDuration` or reusing existing fields:** Always add explicit new fields (`status`, `statusNotes`) for clarity and forward-compatibility.
- **Running `_computeDailySummaries()` in `build()`:** It is already called inside `_buildRekapHarian()` which is called only from `TabBarView`. This is acceptable since Flutter's build can call it on re-renders. For large datasets, consider caching the result, but with 14 employees and 7-day windows the performance is not a concern.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| UTC-to-local time conversion | Custom timezone offset math | `DateTime.toLocal()` (already used in codebase) | Dart's DateTime handles DST correctly |
| Date arithmetic (prior day) | String manipulation on "YYYY-MM-DD" | `DateTime.subtract(const Duration(days: 1))` | Handles month/year boundaries correctly |
| Supabase full fetch | Manual multi-page loop | Remove `.range()` from query | Single query without `.range()` returns all rows up to PostgREST default max |
| Duration formatting | Custom `Duration.toString()` | Existing `_durationStr()` helper already in file | Already handles edge cases (`inMinutes <= 0 → '-'`) |
| Status color mapping | New color constants | Reuse `AttendanceType.color` from `attendance_log.dart` (`sakit: Color(0xFFDC2626)`, `izin: Color(0xFF2563EB)`) | Consistent with existing Per-Scan tile colors |

**Key insight:** All required utilities already exist in the codebase. This phase is pure logic rearrangement.

---

## Common Pitfalls

### Pitfall 1: Supabase PostgREST Default Row Limit

**What goes wrong:** Supabase PostgREST has a server-side default row limit (typically 1000 rows). If a date range returns > 1000 attendance logs, the full fetch will still be silently truncated.

**Why it happens:** PostgREST `max_rows` setting on the Supabase project. The current project has 89 rows total, so this is not an active risk today.

**How to avoid:** For now: document the limitation. The production-safe approach if scale is reached is to add pagination to `_loadDailySummaryData()` too, but for the current 14-employee scale (max ~14 × 4 scans/day × 30 days = 1680 rows/month), this could theoretically be hit on a 30-day query. Consider adding `.limit(2000)` explicitly as a documented safety valve rather than relying on the server default.

**Warning signs:** Rekap Harian shows fewer employees than expected for long date ranges.

**Confidence:** MEDIUM — verified from Supabase PostgREST behavior; specific `max_rows` value for this project not confirmed.

### Pitfall 2: `_computeDailySummaries()` Still Referenced to `_rows`

**What goes wrong:** After adding `_dailyRows`, forgetting to update `_computeDailySummaries()` to use `_dailyRows` instead of `_rows`. The compiler won't catch this — both have the same type.

**Why it happens:** It's a silent correctness bug — no compilation error.

**How to avoid:** The refactor is a single-line change: `final sorted = [..._dailyRows]` instead of `[..._rows]`. Verify via code review that `_rows` is not referenced inside `_computeDailySummaries()` after the fix.

### Pitfall 3: Map Mutation During Iteration (Noon Rule)

**What goes wrong:** Mutating `groups` inside the `groups.forEach()` or `for (final entry in groups.entries)` loop throws `ConcurrentModificationError` at runtime.

**Why it happens:** Dart's `Map.entries` iteration does not allow modification of the map during traversal.

**How to avoid:** Collect all mutations (keys to remove, rows to add) in separate data structures during the traversal. Apply mutations after the loop completes. Pattern 3 above demonstrates the correct approach.

**Warning signs:** `ConcurrentModificationError` crash on Rekap Harian tab when a cross-day shift is present.

### Pitfall 4: Double State Rebuild on Simultaneous Fetches

**What goes wrong:** Calling `_loadReport()` and `_loadDailySummaryData()` both call `setState()` independently. If they complete very close together, Flutter may try to rebuild twice in rapid succession. This is harmless on modern Flutter but can cause a brief flash.

**Why it happens:** Each async fetch has its own `setState()` call.

**How to avoid:** This is acceptable for the current scale. If it becomes visually noticeable, use `Future.wait([_loadReport(), _loadDailySummaryData()])` and batch the setState into a single call after both complete. Not required for Phase 1 but worth noting.

### Pitfall 5: The `notes` Field in `AttendanceLog`

**What goes wrong:** Assuming `notes` is always non-null for sakit/izin entries and displaying it unconditionally.

**Why it happens:** `notes` is `String?` — nullable. Admin may record sakit/izin without a reason.

**How to avoid:** Always null-check and empty-string-check before displaying notes. Pattern 2 above shows `if (summary.statusNotes != null && summary.statusNotes!.isNotEmpty)`.

### Pitfall 6: `_hasLoaded && _rows.isNotEmpty` Guards Tab Visibility

**What goes wrong:** The tab bar + export bar are only shown when `_hasLoaded && _rows.isNotEmpty`. If BUG-002 is fixed but `_rows` (Per-Scan page 1) is empty while `_dailyRows` has data, the Rekap Harian tab will not appear.

**Why it happens:** The visibility condition was designed around `_rows` being the only data source.

**How to avoid:** This is acceptable behavior for Phase 1 — if there are truly 0 scans in Per-Scan mode, Rekap Harian would also be empty. The only edge case is if `_selectedOutletId` filtering causes `_rows` to be empty but `_dailyRows` has data. In practice these are the same query scope, so this is not a real issue. Document it as a known behavior.

---

## Code Examples

Verified patterns from the existing codebase:

### Supabase Full Fetch (no pagination)
```dart
// Source: admin_reports_screen.dart lines 106-118 (current paginated version)
// Fixed version — remove the .range() call:
final data = await SupabaseClientFactory.admin
    .from('attendance_logs')
    .select('*, employees(*), outlets(*)')
    .gte('scanned_at', start.toUtc().toIso8601String())
    .lte('scanned_at', end.toUtc().toIso8601String())
    .eq('scan_outlet_id', _selectedOutletId!)  // optional filter
    .order('scanned_at', ascending: true);
// No .range() → returns all matching rows
```

### AttendanceType Detection
```dart
// Source: attendance_log.dart — AttendanceType enum values confirmed
// sakit → AttendanceType.sakit
// izin  → AttendanceType.izin
// masuk → AttendanceType.masuk
// Detection:
final hasMasuk = rows.any((r) => r.log.type == AttendanceType.masuk);
final hasSakit = rows.any((r) => r.log.type == AttendanceType.sakit);
```

### Accessing `notes` Field
```dart
// Source: attendance_log.dart line 111 — `notes` is String? on AttendanceLog
// Accessing via _ReportRow:
final notes = row.log.notes; // String? — may be null
```

### DateTime Local Conversion (existing pattern)
```dart
// Source: admin_reports_screen.dart line 257
final dt = DateTime.tryParse(row.log.scannedAt)?.toLocal();
// This pattern is already used throughout the file — continue using it
```

### Existing Duration Formatter
```dart
// Source: admin_reports_screen.dart lines 824-831 — already handles edge cases
String _durationStr(Duration? d) {
  if (d == null || d.inMinutes <= 0) return '-';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}j';
  return '${h}j ${m}m';
}
```

---

## State of the Art

| Old Approach | Current Approach After Fix | Impact |
|--------------|---------------------------|--------|
| `_computeDailySummaries()` reads paginated `_rows` | Reads full `_dailyRows` (separate fetch, no `.range()`) | Correct data for all date ranges |
| `_DailySummary` has no status field | `_DailySummary` has `DailySummaryStatus status` + `String? statusNotes` | Enables conditional rendering |
| `_DailySummaryTile` always renders 4 time cells | Renders badge row when `status == sakit` or `izin` | Correct display for sick/leave days |
| Grouping key = `scanned_at` local date | Two-pass grouping with noon-rule re-attachment | Cross-day shifts grouped correctly |

---

## Open Questions

1. **Supabase PostgREST row limit**
   - What we know: Default limit is project-configurable; current data (89 rows) is far below any limit
   - What's unclear: The exact `max_rows` setting on project `tmapxdftdhxovthgbhww`
   - Recommendation: Add `.limit(5000)` to `_loadDailySummaryData()` as an explicit safety valve. For 14 employees × 4 scans/day × 365 days = ~20,000 rows/year, the 5000 limit covers up to 90-day ranges which is the realistic maximum admin query.

2. **Mixed sakit+masuk edge case (REQ-M1-01 acceptance note)**
   - What we know: REQ says "Days with mixed scans (masuk + sakit erroneously) → show masuk normally"
   - What's unclear: Is this a data-entry error scenario or an intentional pattern?
   - Recommendation: The `!hasMasuk && hasSakit` condition naturally handles this: if masuk exists, status = normal and 4 cells are shown. No special case needed.

3. **Rekap Harian loading state during initial load vs. reset**
   - What we know: `_loadReport(reset: true)` is triggered by the "Tampilkan" button
   - What's unclear: Should `_loadingDaily = true` block the entire tab or just show a spinner in the Rekap tab?
   - Recommendation: Show spinner only within `_buildRekapHarian()` — the Per-Scan tab shows its own loader via `_loading`. Each tab has independent loading state.

---

## Validation Architecture

> nyquist_validation config not found — including section based on available test infrastructure.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (built-in Flutter SDK) |
| Config file | none — uses `pubspec.yaml` dev_dependencies |
| Quick run command | `C:\flutter\bin\flutter.bat test test/` |
| Full suite command | `C:\flutter\bin\flutter.bat test --coverage` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-M1-01 | sakit/izin day → `DailySummaryStatus.sakit/izin` set, not `normal` | unit | `C:\flutter\bin\flutter.bat test test/screens/admin/rekap_harian_test.dart` | No — Wave 0 |
| REQ-M1-01 | mixed masuk+sakit day → status = normal | unit | same file | No — Wave 0 |
| REQ-M1-02 | `_computeDailySummaries()` reads `_dailyRows` not `_rows` | unit | same file | No — Wave 0 |
| REQ-M1-03 | pulang at 06:00 Day+1 re-attached to Day0 group | unit | same file | No — Wave 0 |
| REQ-M1-03 | pulang at 14:00 Day+1 NOT re-attached (past noon) | unit | same file | No — Wave 0 |
| REQ-M1-01 | Tile renders badge widget for sakit day | widget | `C:\flutter\bin\flutter.bat test test/screens/admin/rekap_harian_widget_test.dart` | No — Wave 0 |

Note: These are Dart-only unit tests of the computation logic. They do NOT require a device, Supabase connection, or NFC hardware.

### Sampling Rate
- **Per task commit:** `C:\flutter\bin\flutter.bat test test/screens/admin/rekap_harian_test.dart`
- **Per wave merge:** `C:\flutter\bin\flutter.bat test`
- **Phase gate:** All tests green + `flutter analyze` reports 0 errors before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/screens/admin/rekap_harian_test.dart` — pure Dart unit tests for `_computeDailySummaries()` logic (status detection, noon rule, full-data reading)
- [ ] `test/screens/admin/rekap_harian_widget_test.dart` — widget test for `_DailySummaryTile` badge rendering

*(Note: Since `_DailySummary`, `_DailySummaryTile`, `_computeDailySummaries()` are all private to `admin_reports_screen.dart` (prefixed with `_`), the unit tests will need to either: (a) test via the public widget interface using `testWidgets`, or (b) the computation functions be extracted to a testable helper class. Option (a) is simpler for Phase 1.)*

---

## Sources

### Primary (HIGH confidence)
- Direct source code inspection of `lib/screens/admin/admin_reports_screen.dart` (1044 lines, full read)
- Direct source code inspection of `lib/models/attendance_log.dart` (167 lines, full read)
- `.planning/REQUIREMENTS.md` — REQ-M1-01, REQ-M1-02, REQ-M1-03 acceptance criteria
- `.planning/PROJECT.md` — BUG-001, BUG-002, BUG-003 root cause analysis
- `.planning/STATE.md` — key decisions already locked
- `pubspec.yaml` — confirmed no new dependencies needed

### Secondary (MEDIUM confidence)
- `.planning/codebase/TESTING.md` — confirmed 0% test coverage, `flutter_test` is the framework
- Supabase PostgREST behavior (no `.range()` = all rows) — confirmed from project's existing query pattern in `_loadOutlets()` which uses no `.range()` and returns all outlets

### Tertiary (LOW confidence — flagged)
- Supabase PostgREST `max_rows` default (1000) — from general knowledge; project-specific value not verified. Flag for validation.

---

## Metadata

**Confidence breakdown:**
- Bug root causes: HIGH — directly read from source code; bugs are unambiguous
- Fix approach: HIGH — all patterns align with existing code conventions in the file
- Code examples: HIGH — derived directly from reading the actual file
- Test gap analysis: HIGH — TESTING.md confirmed 0% coverage, flutter_test confirmed as framework
- Supabase row limit pitfall: MEDIUM — behavior confirmed from codebase pattern; specific project limit LOW

**Research date:** 2026-02-28
**Valid until:** 2026-03-30 (stable codebase, no fast-moving dependencies for this phase)
