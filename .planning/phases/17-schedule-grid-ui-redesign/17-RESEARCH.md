# Phase 17: Schedule Grid UI Redesign - Research

**Researched:** 2026-03-13
**Domain:** Flutter UI Refactoring — `two_dimensional_scrollables` TableView, Widget Extraction, Schedule Grid
**Confidence:** HIGH

## Summary

Phase 17 is a **rendering-only refactor** of the existing `shift_scheduler_screen.dart` (1,195 lines). The current implementation uses a fragile dual-ListView manual scroll sync pattern that will be replaced by `two_dimensional_scrollables` v0.3.8's `TableView` widget — an official Flutter team package providing true 2D scrolling with first-class pinned rows and columns.

The data layer (Supabase CRUD, SQLite cache via `ScheduleSQLiteService`, schedule models, PDF export) is **production-proven** at 4 outlets with 14 employees and must remain **completely untouched**. Every data method (`_loadData`, `_saveSchedule`, `_loadScheduleFromSupabase`, `_addShift`, `_removeEntry`, `_bulkAssign`, `_generateAutoSchedule`, `_exportToPdf`) will be copy-pasted verbatim into the refactored file(s).

The primary technical risk is verifying that `TableView.builder` supports all current interaction patterns — tap handlers on cells, checkbox widgets inside pinned column cells, and conditional cell styling. Source code analysis of the package (v0.3.8) confirms: `TableViewCell` wraps any `Widget child`, so `GestureDetector`, `Checkbox`, `InkWell`, and arbitrary Flutter widgets all work inside cells. The `TableSpan.backgroundDecoration` with `SpanDecoration(color: ...)` enables column-level background coloring for the "today" highlight.

**Primary recommendation:** Replace dual-ListView + manual scroll sync with `TableView.builder(pinnedRowCount: 1, pinnedColumnCount: 1)`. Extract widget code into separate files while keeping all data methods in the main screen file.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| GRID-01 | Admin melihat jadwal mingguan dalam format grid (karyawan di baris, Senin-Minggu di kolom) | `TableView.builder` with `rowCount: employees.length + 1`, `columnCount: 8` (1 name + 7 days). Already have `_startDate` + 7-day generation pattern in existing code. |
| GRID-02 | Admin tap cell untuk assign shift type (Pagi/Siang/Sore/Libur) ke karyawan pada hari tertentu | `TableViewCell(child: GestureDetector(...))` — verified: cellBuilder returns any Widget child. Existing `_showShiftPicker()` and `_addShift()` logic reused verbatim. |
| GRID-03 | Kolom nama karyawan tetap terlihat (pinned) saat scroll horizontal | `TableView.builder(pinnedColumnCount: 1)` — first-class API. Column 0 = employee names, stays visible. |
| GRID-04 | Header hari (Senin-Minggu) tetap terlihat (pinned) saat scroll vertikal | `TableView.builder(pinnedRowCount: 1)` — first-class API. Row 0 = day headers, stays visible. |
| GRID-05 | Setiap shift type ditampilkan dengan warna berbeda (chip berwarna di cell) | Existing color map: Pagi=#3B82F6, Siang=#F59E0B, Sore=#F97316, Libur=#DC2626. Same `_chip()` builder reused inside `TableViewCell`. |
| GRID-06 | Status Sakit/Izin ditampilkan sebagai overlay pada cell grid | Existing `_getSakitIzin()` + `_hasTimeOff()` logic reused. Cell builder checks these before rendering shift chip. |
| GRID-07 | Admin dapat navigasi antar minggu (← minggu sebelumnya / minggu berikutnya →) | Existing `_buildHeader()` with ← → buttons that modify `_startDate` and call `_loadData()`. Completely unchanged. |
| GRID-08 | Jadwal tersimpan ke Supabase + SQLite cache seperti sebelumnya | Data layer 100% untouched. `_saveSchedule()` does Supabase INSERT + SQLite write-through. `_loadData()` does Supabase-first with SQLite fallback. |
| GRID-09 | Bulk assign mode — pilih beberapa karyawan, assign shift yang sama sekaligus | Existing `_isBulkMode`, `_selectedEmployeeIds`, `_toggleBulkMode()`, `_showBulkAssignSheet()`, `_bulkAssign()` reused. Checkboxes go inside `_buildEmployeeCell()` in column 0 of TableView. |
| GRID-10 | Auto-generate jadwal dari template shift (2-shift/3-shift) | Existing `_generateAutoSchedule()` with template picker dialog reused verbatim. |
</phase_requirements>

## Standard Stack

### Core (New Addition)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `two_dimensional_scrollables` | ^0.3.8 | 2D scrolling grid with pinned rows/columns | Official Flutter team package. Replaces manual dual-ListView scroll sync. SDK >=3.9.0 compatible with project Dart 3.11.0 / Flutter 3.41.1. Verified via `flutter pub add --dry-run`. |

### Existing (UNCHANGED)
| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| `flutter_riverpod` | ^2.6.1 | State management (AppProvider) | Keep as-is |
| `supabase_flutter` | ^2.8.4 | Schedule CRUD to Supabase | Keep as-is |
| `sqflite` | ^2.4.1 | ScheduleSQLiteService offline cache | Keep as-is |
| `intl` | ^0.19.0 | Date formatting for grid headers | Keep as-is |
| `pdf` | ^3.10.8 | PDF export of schedule | Keep as-is |
| `printing` | ^5.13.4 | PDF printing/sharing | Keep as-is |
| `screenshot` | ^3.0.0 | Schedule screenshot export | Keep as-is |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `two_dimensional_scrollables` | Keep manual dual-ListView | Works but fragile, no diagonal scroll, 40+ lines of sync boilerplate. This is a redesign — take the upgrade. |
| `two_dimensional_scrollables` | `pluto_grid` v8.1.0 | Massive (300+ KB) for 14×7 grid. Enterprise spreadsheet overkill. |
| `two_dimensional_scrollables` | `data_table_2` v2.7.2 | Only single-axis scroll. No 2D scroll with pinned rows AND columns. |

### Installation
```bash
cd absensi_enakko_flutter
flutter pub add two_dimensional_scrollables
```

## Architecture Patterns

### Current File Structure (Before)
```
lib/screens/admin/
└── shift_scheduler_screen.dart     # 1,195 lines — MONOLITH (state + data + UI)
```

### Recommended File Structure (After)
```
lib/screens/admin/
├── shift_scheduler_screen.dart              # ~600 lines — state, data methods, scaffold
└── widgets/
    ├── schedule_table_view.dart              # ~120 lines — TableView wrapper
    ├── schedule_cells.dart                   # ~200 lines — cell builder widgets
    └── schedule_legend.dart                  # ~50 lines — legend chip row
```

**Total: ~970 lines (down from 1,195) with much better separation of concerns.**

### Pattern 1: TableView.builder Cell Dispatch
**What:** Single `cellBuilder` callback dispatches to typed cell widget methods
**When:** Always — this is the core rendering pattern

```dart
// Source: two_dimensional_scrollables v0.3.8 API + existing screen logic
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

TableView.builder(
  pinnedRowCount: 1,    // Header row (Sen, Sel, Rab, Kam, Jum, Sab, Min)
  pinnedColumnCount: 1, // Employee name column
  columnCount: 8,       // 1 name + 7 days
  rowCount: _employees.length + 1, // +1 header
  cellBuilder: (BuildContext context, TableVicinity vicinity) {
    // Corner cell (row 0, col 0) — "KARYAWAN" label or bulk select-all
    if (vicinity.row == 0 && vicinity.column == 0) {
      return TableViewCell(child: _buildCornerCell());
    }
    // Header row — day name + date
    if (vicinity.row == 0) {
      final dayIndex = vicinity.column - 1;
      final date = _startDate.add(Duration(days: dayIndex));
      return TableViewCell(child: _buildHeaderCell(date));
    }
    // Employee column — name + leave badge + bulk checkbox
    if (vicinity.column == 0) {
      final empIndex = vicinity.row - 1;
      return TableViewCell(child: _buildEmployeeCell(_employees[empIndex]));
    }
    // Shift cell — chip or empty with tap handler
    final empIndex = vicinity.row - 1;
    final dayIndex = vicinity.column - 1;
    final date = _startDate.add(Duration(days: dayIndex));
    return TableViewCell(child: _buildShiftCell(_employees[empIndex], date));
  },
  columnBuilder: (int index) {
    if (index == 0) {
      // Employee name column — fixed 120px
      return const TableSpan(
        extent: FixedTableSpanExtent(120),
      );
    }
    // Day columns — fill remaining space equally, min 65px
    final dayIndex = index - 1;
    final date = _startDate.add(Duration(days: dayIndex));
    final isToday = _isToday(date);
    return TableSpan(
      extent: const MaxTableSpanExtent(
        FixedTableSpanExtent(75),
        FractionalTableSpanExtent(1 / 7),
      ),
      backgroundDecoration: isToday
        ? TableSpanDecoration(color: Colors.amber.withOpacity(0.08))
        : null,
    );
  },
  rowBuilder: (int index) {
    if (index == 0) {
      // Header row — fixed 44px
      return const TableSpan(
        extent: FixedTableSpanExtent(44),
        backgroundDecoration: TableSpanDecoration(
          color: Color(0xFFFAFAFB), // subtle header bg
        ),
      );
    }
    // Data rows — fixed 56px (slightly taller than current 52px for touch)
    return TableSpan(
      extent: const FixedTableSpanExtent(56),
      foregroundDecoration: const TableSpanDecoration(
        border: TableSpanBorder(
          trailing: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
      ),
    );
  },
  diagonalDragBehavior: DiagonalDragBehavior.free, // allow diagonal scroll
)
```

**Key API findings from source code analysis:**
- `TableVicinity` has `.row` and `.column` getters (not `.xIndex`/`.yIndex`)
- `TableViewCell(child: anyWidget)` — any Flutter widget works as cell content
- `TableSpan.backgroundDecoration` accepts `SpanDecoration(color: ...)` for column/row backgrounds
- `TableSpan.foregroundDecoration` draws ON TOP of cell content — use for borders
- `SpanBorder` has `.leading` and `.trailing` (not top/bottom/left/right)
- `DiagonalDragBehavior.free` enables simultaneous H+V scrolling (essential for tablet)
- `FixedTableSpanExtent(px)` for fixed sizes, `FractionalTableSpanExtent(frac)` for viewport fractions
- `MaxTableSpanExtent(a, b)` combines two extents (take the larger) — perfect for min-width + fill

### Pattern 2: Preserve Data Layer Interface (CRITICAL)
**What:** All data methods copied verbatim — zero changes to any Supabase/SQLite code
**When:** During the entire refactor — this is a safety constraint

```dart
// These methods are COPY-PASTE UNCHANGED into refactored file:
// ─── Data Loading ───
// _loadData()
// _loadScheduleFromSupabase()
// _loadSakitIzinData()
// _loadTimeOffRequests()
// _loadCarryOverBalance()
//
// ─── Data Manipulation ───
// _addShift()
// _removeEntry()
// _bulkAssign()
// _generateAutoSchedule()
//
// ─── Data Persistence ───
// _saveSchedule()
// _exportToPdf()
//
// ─── Helpers ───
// _getSakitIzin()
// _hasTimeOff()
// _showTimeOffDialog()
// _showSuccess()
// _showError()
// _getStartOfWeek()
```

### Pattern 3: Today Column Highlight via SpanDecoration
**What:** Use `TableSpan.backgroundDecoration` to paint column bg for today's date
**When:** In `columnBuilder` — compare day's date with `DateTime.now()`

```dart
bool _isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month && date.day == now.day;
}

// In columnBuilder:
backgroundDecoration: isToday
  ? const TableSpanDecoration(color: Color(0x14F59E0B)) // 8% amber
  : null,
```

### Pattern 4: Animated Cell Transitions
**What:** Smooth visual feedback when shift changes in a cell
**When:** On every cell rebuild after `setState` from `_addShift` or `_removeEntry`

```dart
Widget _buildShiftContent(ScheduleEntry? entry) {
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    transitionBuilder: (child, animation) => ScaleTransition(
      scale: animation, child: child,
    ),
    child: entry == null
      ? Container(
          key: const ValueKey('empty'),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.add, size: 14, color: Colors.grey.shade400),
        )
      : Container(
          key: ValueKey(entry.shift.name),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: entry.shift.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: entry.shift.color.withOpacity(0.3)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(_shiftIcon(entry.shift.name), size: 10, color: entry.shift.color),
            const SizedBox(width: 2),
            Text(entry.shift.name, style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: entry.shift.color)),
          ]),
        ),
  );
}
```

### Anti-Patterns to Avoid
- **Touching data methods:** Any modification to `_loadData()`, `_saveSchedule()`, `_loadScheduleFromSupabase()`, or any Supabase/SQLite code risks breaking production at 4 outlets. These are copy-paste only.
- **Giant cellBuilder switch:** Don't put 200 lines in `cellBuilder`. Dispatch to `_buildCornerCell()`, `_buildHeaderCell()`, `_buildEmployeeCell()`, `_buildShiftCell()` — each <30 lines.
- **Manual scroll controllers:** Don't bring `ScrollController` sync code into the new design. `TableView` handles all scrolling internally. Remove `_employeeListController`, `_scheduleGridController`, `_horizontalScrollController`, `_isSyncing`, `_setupScrollSync()`.
- **Drag-and-drop:** Out of scope. `two_dimensional_scrollables` doesn't support drag across cells. Tap-to-assign is the correct pattern for tablet.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 2D scrolling with pinned rows/columns | Dual-ListView with manual `ScrollController.jumpTo()` sync | `TableView.builder(pinnedRowCount: 1, pinnedColumnCount: 1)` | Eliminates ~45 lines of fragile sync code. True diagonal scrolling. Single viewport = better perf. |
| Column background highlighting | Custom `CustomPainter` layer behind cells | `TableSpan.backgroundDecoration: SpanDecoration(color: ...)` | Built into the framework. Handles pinned/unpinned separation automatically. |
| Row/column borders | Manual `BoxDecoration` on every cell container | `TableSpan.foregroundDecoration: SpanDecoration(border: SpanBorder(...))` | Paints once per row/column, not per cell. Cleaner and more performant. |
| Cell transition animations | Manual `AnimationController` management | `AnimatedSwitcher` + `AnimatedContainer` (built-in Flutter) | Already using similar patterns. Zero new dependencies. |
| Responsive column widths | `LayoutBuilder` + manual `clamp` calculation | `MaxTableSpanExtent(FixedTableSpanExtent(75), FractionalTableSpanExtent(1/7))` | Built-in extent combining. Cleaner than manual math. |

**Key insight:** The `two_dimensional_scrollables` package handles the two hardest problems in the current code (scroll sync and pinning). Everything else is Flutter built-in widgets.

## Common Pitfalls

### Pitfall 1: Breaking Data Layer During Refactor
**What goes wrong:** While refactoring 1,195 lines, developer "cleans up" data loading or save methods, introducing bugs in Supabase ↔ SQLite sync.
**Why it happens:** Data and rendering code are interleaved. It's tempting to refactor everything.
**How to avoid:** Treat data methods as a black box. Copy verbatim. Test save/load before AND after.
**Warning signs:** Schedule saved in app but not in Supabase. Week nav shows stale data. PDF differs from grid.

### Pitfall 2: Scroll Controller Cleanup
**What goes wrong:** New code still creates `ScrollController` instances from old pattern, causing memory leaks or conflicts with `TableView`'s internal scroll management.
**Why it happens:** Copy-paste from old file includes `initState` scroll setup.
**How to avoid:** Remove ALL of: `_employeeListController`, `_scheduleGridController`, `_horizontalScrollController`, `_isSyncing`, `_setupScrollSync()`. The `TableView` manages its own scrolling.
**Warning signs:** Scroll position jumping, assertion errors about attached controllers.

### Pitfall 3: Bulk Mode Checkbox Alignment
**What goes wrong:** After removing dual-ListView, bulk mode checkboxes don't visually align with schedule rows.
**Why it happens:** Old bulk mode relied on separate employee list and schedule grid being scroll-synced.
**How to avoid:** In `TableView`, column 0 IS the employee column in the same grid. Checkbox goes inside `_buildEmployeeCell()` within the TableView. Alignment is guaranteed because it's one viewport.
**Warning signs:** Selecting employee selects wrong person.

### Pitfall 4: TableViewCell Must Wrap Every Cell Return
**What goes wrong:** `cellBuilder` returns a plain `Widget` instead of `TableViewCell(child: widget)`, causing type errors.
**Why it happens:** `cellBuilder` signature returns `TableViewCell`, not `Widget`. Easy to forget the wrapper.
**How to avoid:** Every return path in `cellBuilder` must be `TableViewCell(child: ...)`.
**Warning signs:** Compile error — "`Widget` can't be assigned to `TableViewCell`".

### Pitfall 5: DiagonalDragBehavior Default
**What goes wrong:** Default is `DiagonalDragBehavior.none` — user can only scroll in one axis at a time. On tablet, this feels broken when trying to scroll diagonally.
**Why it happens:** Package defaults to `none` for safety. Developer forgets to override.
**How to avoid:** Explicitly set `diagonalDragBehavior: DiagonalDragBehavior.free` on `TableView.builder`.
**Warning signs:** Grid scrolls only horizontally OR vertically, not both simultaneously.

### Pitfall 6: Row Height Mismatch
**What goes wrong:** Current code uses `height: 52` for cells. If `FixedTableSpanExtent` uses a different value, cells look wrong.
**Why it happens:** Different number in `rowBuilder` vs cell widget constraints.
**How to avoid:** Use `FixedTableSpanExtent(56)` in `rowBuilder` (slightly larger for better touch targets). Don't also set `height` constraints on the cell widgets — let TableView control sizing.
**Warning signs:** Cell content clipped or oddly spaced.

### Pitfall 7: Missing `useRootNavigator: false` on Dialogs
**What goes wrong:** Existing dialogs use `useRootNavigator: false` (critical for GoRouter nested navigation). If copied incorrectly, dialogs pop the wrong navigator.
**Why it happens:** `useRootNavigator: false` appears on `_showShiftPicker()`, `_showTimeOffDialog()`, and `_generateAutoSchedule()` dialogs. Easy to miss during copy.
**How to avoid:** Copy dialog methods verbatim. Verify `useRootNavigator: false` is present on all `showDialog` and `showModalBottomSheet` calls.
**Warning signs:** Tapping "Batal" navigates away from the entire scheduler instead of just closing the dialog.

## Code Examples

### Complete TableView Integration (Verified from Source)
```dart
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

// In _buildTable() — replaces the entire Row + Container + ListView.builder pattern
Widget _buildTable() {
  if (_employees.isEmpty) {
    return const Center(child: Text('Tidak ada karyawan'));
  }
  final days = List.generate(7, (i) => _startDate.add(Duration(days: i)));
  
  return TableView.builder(
    diagonalDragBehavior: DiagonalDragBehavior.free,
    pinnedRowCount: 1,
    pinnedColumnCount: 1,
    columnCount: 8, // 1 name + 7 days
    rowCount: _employees.length + 1, // +1 header
    cellBuilder: (BuildContext context, TableVicinity vicinity) {
      if (vicinity.row == 0 && vicinity.column == 0) {
        return TableViewCell(child: _buildCornerCell());
      }
      if (vicinity.row == 0) {
        return TableViewCell(
          child: _buildHeaderCell(days[vicinity.column - 1]),
        );
      }
      if (vicinity.column == 0) {
        return TableViewCell(
          child: _buildEmployeeCell(_employees[vicinity.row - 1]),
        );
      }
      return TableViewCell(
        child: _buildShiftCell(
          _employees[vicinity.row - 1],
          days[vicinity.column - 1],
        ),
      );
    },
    columnBuilder: (int index) {
      if (index == 0) {
        return const TableSpan(extent: FixedTableSpanExtent(120));
      }
      final dayIndex = index - 1;
      final date = days[dayIndex];
      final isToday = _isToday(date);
      return TableSpan(
        extent: const MaxTableSpanExtent(
          FixedTableSpanExtent(75),
          FractionalTableSpanExtent(1 / 7),
        ),
        backgroundDecoration: isToday
          ? TableSpanDecoration(color: Colors.amber.withOpacity(0.08))
          : null,
        foregroundDecoration: const TableSpanDecoration(
          border: TableSpanBorder(
            trailing: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
          ),
        ),
      );
    },
    rowBuilder: (int index) {
      if (index == 0) {
        return const TableSpan(
          extent: FixedTableSpanExtent(44),
        );
      }
      return const TableSpan(
        extent: FixedTableSpanExtent(56),
        foregroundDecoration: TableSpanDecoration(
          border: TableSpanBorder(
            trailing: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
          ),
        ),
      );
    },
  );
}
```

### Shift Cell With Tap Handler (GestureDetector Inside TableViewCell)
```dart
Widget _buildShiftCell(Employee emp, DateTime date) {
  // Check sakit/izin first (same logic as current _buildDayCell)
  final sakitIzin = _getSakitIzin(emp.id, date);
  if (sakitIzin != null) {
    return Container(
      padding: const EdgeInsets.all(4),
      alignment: Alignment.center,
      child: _chip(sakitIzin.label, sakitIzin.color, Icons.medical_services),
    );
  }
  
  if (_hasTimeOff(emp.id, date)) {
    return Container(
      padding: const EdgeInsets.all(4),
      alignment: Alignment.center,
      child: _chip('Libur', const Color(0xFFDC2626), Icons.beach_access),
    );
  }
  
  final entries = _currentSchedule!.entries.where((e) =>
    e.employeeId == emp.id &&
    e.date.year == date.year &&
    e.date.month == date.month &&
    e.date.day == date.day,
  ).toList();
  
  if (entries.isEmpty) {
    return GestureDetector(
      onTap: () => _showShiftPicker(emp, date),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(Icons.add, size: 18, color: Colors.grey.shade400),
      ),
    );
  }
  
  final entry = entries.first;
  return GestureDetector(
    onTap: () => _removeEntry(entry.id),
    child: Container(
      padding: const EdgeInsets.all(4),
      alignment: Alignment.center,
      child: _buildShiftChip(entry),
    ),
  );
}
```

### Employee Cell With Bulk Checkbox (Verified Pattern)
```dart
Widget _buildEmployeeCell(Employee emp) {
  final isSelected = _selectedEmployeeIds.contains(emp.id);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    decoration: BoxDecoration(
      color: _isBulkMode && isSelected ? Colors.orange.withOpacity(0.08) : Colors.grey.shade50,
    ),
    child: Row(children: [
      if (_isBulkMode)
        SizedBox(
          width: 28, height: 28,
          child: Checkbox(
            value: isSelected,
            onChanged: (_) => setState(() {
              isSelected
                ? _selectedEmployeeIds.remove(emp.id)
                : _selectedEmployeeIds.add(emp.id);
            }),
            activeColor: Colors.orange,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      if (!_isBulkMode) const SizedBox(width: 4),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emp.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          if ((_leaveBalance[emp.id] ?? 0) > 0)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('+${_leaveBalance[emp.id]}',
                style: TextStyle(fontSize: 8, color: Colors.orange.shade800)),
            ),
        ],
      )),
      if (!_isBulkMode)
        Material(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _showTimeOffDialog(emp),
            child: Container(
              width: 28, height: 28, alignment: Alignment.center,
              child: Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade700),
            ),
          ),
        ),
    ]),
  );
}
```

## State of the Art

| Old Approach (Current) | New Approach (Redesign) | Impact |
|-------------------------|-------------------------|--------|
| Dual `ListView.builder` with `_isSyncing` flag + `ScrollController.jumpTo()` | Single `TableView.builder` with built-in 2D scroll | Eliminates ~45 lines sync code, adds diagonal scroll, single viewport perf |
| Manual `Row` + `Container(width: 110)` for pinned employee column | `pinnedColumnCount: 1` + `FixedTableSpanExtent(120)` | Framework-managed pinning, no manual positioning |
| `LayoutBuilder` + `clamp` for column widths | `MaxTableSpanExtent(Fixed, Fractional)` | Declarative extent definition, framework handles layout |
| No "today" column highlight | `TableSpan.backgroundDecoration: SpanDecoration(color)` | Visual anchor for current day |
| Cell borders via `BoxDecoration` on every cell | `TableSpan.foregroundDecoration` with `SpanBorder` | Paint once per row/column, not per cell |

**Deprecated/outdated (removed in this refactor):**
- `_employeeListController`, `_scheduleGridController`, `_horizontalScrollController` — replaced by TableView internal scroll management
- `_isSyncing` flag and `_setupScrollSync()` — no longer needed
- `SingleChildScrollView(scrollDirection: Axis.horizontal)` wrapping — TableView handles both axes

## Refactoring Map

### What Changes (Rendering Only)
| Line Range | Current Code | New Code | Risk |
|------------|-------------|----------|------|
| 52-55 | Three `ScrollController` declarations | Remove entirely | LOW — TableView manages its own |
| 58-60 | `initState` calls `_setupScrollSync()` | Remove `_setupScrollSync()` call | LOW |
| 70-86 | `_setupScrollSync()` method (16 lines) | Delete entirely | LOW |
| 88-94 | `dispose()` for 3 controllers | Remove scroll controller disposal | LOW |
| 952-1026 | `_buildTable()` — dual-ListView with manual sync | Replace with `TableView.builder(...)` | MEDIUM — core change |
| 1028-1083 | `_buildEmployeeCell()` | Move into cell builder, same logic | LOW |
| 1086-1091 | `_buildScheduleRow()` | Remove — cells are built individually by TableView | LOW |
| 1094-1147 | `_buildDayCell()` | Rename to `_buildShiftCell()`, same logic | LOW |

### What Stays Unchanged (Data Layer)
| Line Range | Method | Lines | Reason |
|------------|--------|-------|--------|
| 96-146 | `_loadData()` | 50 | Supabase-first + SQLite fallback. Production-proven. |
| 148-204 | `_loadScheduleFromSupabase()` | 56 | Supabase query + entry parsing. |
| 206-224 | `_loadSakitIzinData()` | 18 | Attendance log query for sakit/izin overlay. |
| 227-243 | `_loadTimeOffRequests()` | 16 | Time off query. |
| 254-294 | `_loadCarryOverBalance()` | 40 | Previous week libur count. |
| 296-307 | `_addShift()` | 11 | Remove old + add new entry. |
| 309-314 | `_removeEntry()` | 5 | Remove entry by ID. |
| 320-369 | `_toggleBulkMode()`, `_toggleSelectAll()`, `_bulkAssign()` | 49 | Bulk assign logic. |
| 372-415 | `_showBulkAssignSheet()` | 43 | Bottom sheet picker. |
| 417-544 | `_generateAutoSchedule()` | 127 | Template rotation + libur calculation. |
| 548-622 | `_showTimeOffDialog()` | 74 | Time off request dialog. |
| 624-712 | `_saveSchedule()` | 88 | Supabase INSERT + old schedule soft-delete + SQLite cache. |
| 714-795 | `_exportToPdf()` | 81 | Merged entries + PdfService call. |
| 797-800 | `_showSuccess()`, `_showError()` | 4 | Snackbar helpers. |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (built-in) |
| Config file | `analysis_options.yaml` (existing) |
| Quick run command | `flutter test test/models/shift_schedule_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GRID-01 | Grid renders employees×days | widget | `flutter test test/screens/admin/schedule_grid_test.dart -x` | ❌ Wave 0 |
| GRID-02 | Tap cell triggers shift assignment | widget | `flutter test test/screens/admin/schedule_grid_test.dart -x` | ❌ Wave 0 |
| GRID-03 | Employee column pinned on H-scroll | manual-only | Visual verification on tablet | N/A — scroll behavior requires real viewport |
| GRID-04 | Header row pinned on V-scroll | manual-only | Visual verification on tablet | N/A — scroll behavior requires real viewport |
| GRID-05 | Shift colors are distinct | unit | `flutter test test/models/shift_schedule_test.dart` | ✅ Existing (ShiftSlot factories test) |
| GRID-06 | Sakit/Izin overlay displayed | widget | `flutter test test/screens/admin/schedule_grid_test.dart -x` | ❌ Wave 0 |
| GRID-07 | Week navigation updates dates | unit | `flutter test test/screens/admin/schedule_grid_test.dart -x` | ❌ Wave 0 |
| GRID-08 | Data persistence unchanged | unit | `flutter test test/models/shift_schedule_test.dart` | ✅ Existing (serialization round-trip tests) |
| GRID-09 | Bulk assign selects multiple employees | widget | `flutter test test/screens/admin/schedule_grid_test.dart -x` | ❌ Wave 0 |
| GRID-10 | Auto-generate creates entries for all employees | unit | `flutter test test/screens/admin/schedule_grid_test.dart -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/models/shift_schedule_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green + manual tablet verification of GRID-03, GRID-04

### Wave 0 Gaps
- [ ] `test/screens/admin/schedule_grid_test.dart` — widget tests for GRID-01, GRID-02, GRID-06, GRID-07, GRID-09, GRID-10
- [ ] `flutter pub add two_dimensional_scrollables` — add dependency
- [ ] `flutter analyze` — verify no new analysis issues after adding dependency

*(Note: GRID-03 and GRID-04 are pinned scroll behaviors that require real viewport interaction — these are manual verification on tablet device)*

## Open Questions

1. **Column width on 10" tablet landscape**
   - What we know: 10" landscape ≈ 1280px width. 120px name + 7 × ~165px per day = 1275px. Fits perfectly.
   - What's unclear: With device density variations, exact column widths may need tuning.
   - Recommendation: Use `MaxTableSpanExtent(FixedTableSpanExtent(75), FractionalTableSpanExtent(1/7))` and verify on target tablet. The fractional extent auto-adapts.

2. **Existing tap-to-remove behavior**
   - What we know: Current code — tapping an assigned shift cell calls `_removeEntry(entry.id)` (removes immediately). This is fast but could be accident-prone.
   - What's unclear: Should the redesign keep tap-to-remove or change to tap-to-reassign (show picker again)?
   - Recommendation: Keep current behavior (tap-to-remove) for zero regression. UI improvement can be a follow-up.

3. **Widget test complexity for TableView**
   - What we know: `TableView` requires a constrained viewport to render. Widget tests need `SizedBox` wrapper with explicit constraints.
   - What's unclear: How well `flutter_test`'s `pumpWidget` handles `two_dimensional_scrollables` internals.
   - Recommendation: Focus unit tests on data logic (already covered by `shift_schedule_test.dart`). Widget tests for cell builders only, not scroll behavior. Manual tablet testing for scroll/pinning.

## Sources

### Primary (HIGH confidence)
- `two_dimensional_scrollables` v0.3.8 source code — read from pub cache: `table.dart`, `table_cell.dart`, `table_delegate.dart`, `table_span.dart`, `span.dart`
- `shift_scheduler_screen.dart` — full 1,195-line source analysis
- `shift_schedule.dart` — model definitions (ShiftSlot, ScheduleEntry, OutletSchedule, ShiftTemplate)
- `schedule_sqlite_service.dart` — SQLite cache service (244 lines)
- `pubspec.yaml` — current dependency versions and SDK constraints
- `flutter pub add --dry-run two_dimensional_scrollables` — verified compatibility: resolves to 0.3.8

### Secondary (MEDIUM confidence)
- `.planning/research/STACK.md` — previous stack research for v3.0
- `.planning/research/ARCHITECTURE.md` — architecture patterns with widget extraction plan
- `.planning/research/PITFALLS.md` — domain pitfalls catalog

### Tertiary (LOW confidence)
- None — all findings verified from source code

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — package verified from pub cache source code, `flutter pub add --dry-run` confirms compatibility
- Architecture: HIGH — `TableView.builder` API fully analyzed, all params verified from source
- Pitfalls: HIGH — derived from actual source code analysis of both the package and existing screen
- Code examples: HIGH — built from verified API signatures, not from training data

**Research date:** 2026-03-13
**Valid until:** 2026-04-13 (stable — package v0.3.8 is mature, existing code is frozen)
