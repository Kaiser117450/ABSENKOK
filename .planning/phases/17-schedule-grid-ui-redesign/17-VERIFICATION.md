---
phase: 17-schedule-grid-ui-redesign
verified: 2026-03-12T18:00:00Z
status: human_needed
score: 12/12 must-haves verified
human_verification:
  - test: "Pinned employee column during horizontal scroll"
    expected: "Employee names (col 0) remain visible as user scrolls right through day columns"
    why_human: "Scroll viewport behavior requires physical tablet — pinnedColumnCount=1 is set in code but runtime pinning only verifiable on device"
  - test: "Pinned header row during vertical scroll"
    expected: "Day headers (Senin-Minggu, row 0) remain visible as user scrolls down through employee rows"
    why_human: "Scroll viewport behavior requires physical tablet — pinnedRowCount=1 is set in code but runtime pinning only verifiable on device"
  - test: "Shift picker dialog opens on empty cell tap"
    expected: "AlertDialog shows 4 shift options (Pagi/Siang/Sore/Libur) with correct colors; selecting one causes the cell to render a colored chip"
    why_human: "Dialog rendering and navigator pop behavior require runtime Flutter context — onCellTap→_showShiftPicker chain is wired in code but dialog UX needs tablet confirmation"
  - test: "Data persistence: save → reload → data present"
    expected: "After assigning shifts and tapping Save, closing and reopening the Jadwal screen shows the saved shifts still in their cells"
    why_human: "Requires live Supabase connection and SQLite write-through — _saveSchedule() method is intact in code but actual DB writes need device verification"
  - test: "Bulk assign mode end-to-end"
    expected: "Tap bulk FAB → checkboxes appear → select ≥2 employees → tap bulk FAB → pick shift → all selected employees get that shift for every day in the week"
    why_human: "_toggleBulkMode/_bulkAssign logic is intact in code but multi-state interaction flow needs tablet confirmation"
  - test: "Auto-generate from template fills grid"
    expected: "Tap auto-generate FAB → template picker appears → select 2-shift or 3-shift → grid fills with rotated shifts and mandatory libur per employee"
    why_human: "_generateAutoSchedule() is present and unchanged but the rotation logic output needs visual confirmation on real data"
---

# Phase 17: Schedule Grid UI Redesign — Verification Report

**Phase Goal:** Redesign the schedule UI from dual-ListView to a proper week-view grid using `two_dimensional_scrollables` TableView with pinned headers.
**Verified:** 2026-03-12
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | TableView.builder configured with `pinnedRowCount: 1` and `pinnedColumnCount: 1` | ✓ VERIFIED | `schedule_table_view.dart` lines 62–63: `pinnedRowCount: 1, pinnedColumnCount: 1` |
| 2 | `DiagonalDragBehavior.free` enabled for simultaneous H+V scroll on tablet | ✓ VERIFIED | `schedule_table_view.dart` line 61: `diagonalDragBehavior: DiagonalDragBehavior.free` |
| 3 | Cell builders render distinct colored chips — Pagi (blue bg), Siang (amber bg), Sore (orange bg), Libur (red bg) | ✓ VERIFIED | `schedule_cells.dart` lines 239–261: switch on `shiftName` → distinct `(bg, fg, icon)` tuples per shift |
| 4 | Legend bar displays all 6 shift/status types (Pagi, Siang, Sore, Libur, Sakit, Izin) with matching colors | ✓ VERIFIED | `schedule_legend.dart` lines 18–23: 6 `_legendChip` calls with hex colors `#3B82F6, #F59E0B, #F97316, #DC2626, #991B1B, #2563EB` |
| 5 | All widget files compile without stub implementations | ✓ VERIFIED | 0 stubs (no `TODO/FIXME/return null/throw UnimplementedError`) found across all 3 widget files; line counts exceed minimums (303/150, 161/100, 49/40) |
| 6 | Empty cell tap → shift picker dialog → colored chip assignment | ✓ VERIFIED | `buildShiftCell` wires `onTapEmpty` → `onCellTap` → `_showShiftPicker`; `_addShift` called from dialog option; chip rendered from `ScheduleEntry` |
| 7 | Assigned cell tap → entry removed → cell reverts to empty | ✓ VERIFIED | `buildShiftCell` wires `onTapAssigned(entry.id)` → `onEntryRemove` → `_removeEntry`; cell falls back to empty container when `entries.isEmpty` |
| 8 | Sakit/Izin from attendance_logs renders as non-tappable overlay in cell | ✓ VERIFIED | `buildShiftCell` checks `sakitIzin != null` FIRST and returns plain `_chip()` with NO `GestureDetector`; `_loadSakitIzinData()` unchanged |
| 9 | ← → week navigation buttons reload correct week data | ✓ VERIFIED | `_buildHeader()` has `Icons.chevron_left/chevron_right` buttons that `setState(() => _startDate ±7days)` then call `_loadData()` |
| 10 | Bulk assign: checkboxes → select employees → assign shift for whole week | ✓ VERIFIED | `_toggleBulkMode`, `_toggleSelectAll`, `_bulkAssign`, `_showBulkAssignSheet` all present (2+ occurrences each); `buildEmployeeCell` renders checkboxes when `isBulkMode` |
| 11 | Auto-generate from template fills grid with rotated shifts | ✓ VERIFIED | `_generateAutoSchedule()` present (2 occurrences); unchanged from original per SUMMARY |
| 12 | Save persists to Supabase + SQLite; PDF export intact — zero data-layer changes | ✓ VERIFIED | `_saveSchedule()`, `_loadScheduleFromSupabase()`, `SupabaseClientFactory.admin` all present; `_exportToPdf()` + `PdfService` import retained; 943-line screen matches SUMMARY claim |

**Score: 12/12 truths verified (automated/static)**

---

## Required Artifacts

| Artifact | Min Lines | Actual | Status | Details |
|----------|-----------|--------|--------|---------|
| `lib/screens/admin/widgets/schedule_cells.dart` | 150 | 303 | ✓ VERIFIED | 5 cell builder functions: `buildCornerCell`, `buildHeaderCell`, `buildEmployeeCell`, `buildShiftCell`, `_chip`; all substantive implementations |
| `lib/screens/admin/widgets/schedule_table_view.dart` | 100 | 161 | ✓ VERIFIED | `ScheduleTableView` StatelessWidget with full `TableView.builder` config, `columnBuilder`, `rowBuilder`, `_isToday` helper |
| `lib/screens/admin/widgets/schedule_legend.dart` | 40 | 49 | ✓ VERIFIED | `ScheduleLegend` with 6 `_legendChip` entries and horizontal scroll wrapper |
| `pubspec.yaml` | — | — | ✓ VERIFIED | `two_dimensional_scrollables: ^0.3.8` present at line 83; resolved in `pubspec.lock` |
| `lib/screens/admin/shift_scheduler_screen.dart` | 550 | 943 | ✓ VERIFIED | Refactored screen uses `ScheduleTableView` + `ScheduleLegend`; all 19 data methods present; old rendering code removed |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `schedule_table_view.dart` | `schedule_cells.dart` | `import 'schedule_cells.dart'` + calls all 4 builder functions | ✓ WIRED | Line 6 import; `buildCornerCell`, `buildHeaderCell`, `buildEmployeeCell`, `buildShiftCell` all called in `cellBuilder` |
| `schedule_cells.dart` | `shift_schedule.dart` | `import '../../../models/shift_schedule.dart'` + uses `OutletSchedule`, `ScheduleEntry` | ✓ WIRED | Line 4 import; `OutletSchedule? schedule` param + `schedule?.entries.where(...)` usage |
| `schedule_table_view.dart` | `two_dimensional_scrollables` | `import 'package:two_dimensional_scrollables/...'` + `TableView.builder` | ✓ WIRED | Line 2 import; `TableView.builder`, `TableVicinity`, `TableSpan`, `FixedTableSpanExtent`, `MaxTableSpanExtent`, `TableSpanDecoration`, `TableSpanBorder`, `DiagonalDragBehavior` all used |
| `shift_scheduler_screen.dart` | `schedule_table_view.dart` | `import 'widgets/schedule_table_view.dart'` + `ScheduleTableView(...)` in `build()` | ✓ WIRED | Line 16 import; `ScheduleTableView` instantiated at line 815 with all 13 required params wired |
| `shift_scheduler_screen.dart` | `schedule_legend.dart` | `import 'widgets/schedule_legend.dart'` + `const ScheduleLegend()` in `build()` | ✓ WIRED | Line 17 import; `ScheduleLegend` used at line 813 in `Column` |
| `shift_scheduler_screen.dart` | Supabase + SQLite | `SupabaseClientFactory.admin` + `ScheduleSQLiteService` — ALL UNCHANGED | ✓ WIRED | `SupabaseClientFactory.admin` used in `_loadData`, `_loadScheduleFromSupabase`, `_loadSakitIzinData`, `_loadTimeOffRequests`, `_loadCarryOverBalance`, `_saveSchedule`; `ScheduleSQLiteService` in `_loadData` and `_saveSchedule` |

---

## Requirements Coverage

| Requirement | Plan | Description | Status | Evidence |
|-------------|------|-------------|--------|---------|
| GRID-01 | 17-01 | Grid format: employees=rows, Mon-Sun=columns | ✓ SATISFIED | `TableView.builder` with `columnCount: 8` (1 name + 7 days), `rowCount: employees.length + 1`; `cellBuilder` dispatches by `vicinity.row`/`vicinity.column` |
| GRID-02 | 17-02 | Tap cell to assign shift (Pagi/Siang/Sore/Libur) | ✓ SATISFIED | `buildShiftCell` → `onTapEmpty` → `_showShiftPicker` → `_addShift`; 4 shift options in AlertDialog |
| GRID-03 | 17-01 | Employee column pinned on horizontal scroll | ✓ SATISFIED (code) | `pinnedColumnCount: 1`; columnBuilder returns `FixedTableSpanExtent(120)` for index 0 — **requires device confirmation** |
| GRID-04 | 17-01 | Header row pinned on vertical scroll | ✓ SATISFIED (code) | `pinnedRowCount: 1`; rowBuilder returns `FixedTableSpanExtent(44)` for index 0 — **requires device confirmation** |
| GRID-05 | 17-01 | Distinct shift colors per chip | ✓ SATISFIED | `schedule_cells.dart` switch: Pagi=`#DBEAFE`/`#1E40AF`, Siang=`#FEF3C7`/`#92400E`, Sore=`#FFEDD5`/`#C2410C`, Libur=`#FEE2E2`/`#991B1B`; legend uses `#3B82F6, #F59E0B, #F97316, #DC2626` |
| GRID-06 | 17-02 | Sakit/Izin overlay in cell (non-tappable) | ✓ SATISFIED | `sakitIzin != null` checked first in `buildShiftCell`; no `GestureDetector` wrapping the overlay chip |
| GRID-07 | 17-02 | Week navigation ← → | ✓ SATISFIED | `_buildHeader()` chevron buttons: subtract/add 7 days to `_startDate` + call `_loadData()` |
| GRID-08 | 17-02 | Persist to Supabase + SQLite | ✓ SATISFIED (code) | `_saveSchedule()` intact (678–757 lines); `SupabaseClientFactory.admin` + `ScheduleSQLiteService.saveSchedule()` — **requires live Supabase to confirm** |
| GRID-09 | 17-02 | Bulk assign mode | ✓ SATISFIED | `_toggleBulkMode`, `_bulkAssign`, `_showBulkAssignSheet` present; checkboxes rendered in `buildEmployeeCell` when `isBulkMode` |
| GRID-10 | 17-02 | Auto-generate from template | ✓ SATISFIED | `_generateAutoSchedule()` present and unchanged per SUMMARY |

**All 10 GRID requirements claimed — all 10 verified in code.**
**No orphaned requirements.** (REQUIREMENTS.md traceability table maps GRID-01–10 exclusively to Phase 17.)

---

## Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `schedule_cells.dart` | None | — | Clean |
| `schedule_table_view.dart` | None | — | Clean |
| `schedule_legend.dart` | None | — | Clean |
| `shift_scheduler_screen.dart` | `// [File lengkap akan saya tulis di response berikut...]` (line 2) | ℹ️ Info | Leftover comment from original file, cosmetic only — no functional impact |

No blockers or warnings found.

---

## Human Verification Required

Plan 02 included a `checkpoint:human-verify` task (gate: blocking) that was **auto-approved via `auto_advance`** — the visual device tests were not performed. The following items need human confirmation on a physical tablet before Phase 17 can be considered production-ready:

### 1. Pinned Employee Column (GRID-03)

**Test:** Open Jadwal Shift screen → scroll the grid horizontally to the right.
**Expected:** Employee names in the leftmost column remain stationary and visible while the 7 day-columns scroll left.
**Why human:** `pinnedColumnCount: 1` is correctly set in code, but actual viewport pinning behavior can only be confirmed at runtime on physical hardware (iOS Simulator/Android emulator behavior differs from tablet).

### 2. Pinned Day Header Row (GRID-04)

**Test:** Open Jadwal Shift screen with ≥8 employees → scroll vertically downward.
**Expected:** The "Sen/Sel/Rab/Kam/Jum/Sab/Min" header row remains at the top of the grid while employee rows scroll.
**Why human:** `pinnedRowCount: 1` is set in code but runtime scroll behavior requires physical viewport.

### 3. Shift Picker Dialog + Cell Update (GRID-02)

**Test:** Tap an empty cell (grey "+" icon) → shift picker dialog should appear → select "Pagi" → dialog closes → cell shows blue "Pagi" chip.
**Expected:** Dialog appears correctly, `useRootNavigator: false` prevents root navigation pop, shift chip renders immediately after selection.
**Why human:** Dialog appearance, navigator context behavior, and immediate setState re-render need runtime Flutter context.

### 4. Data Persistence End-to-End (GRID-08)

**Test:** Assign 3–5 shifts → tap Save button → force-close app → reopen → navigate to same week → verify shifts are still there.
**Expected:** Shifts are stored in Supabase and loaded back; if offline, SQLite cache serves the data.
**Why human:** Requires live Supabase connection; DB write/read cycle cannot be statically verified.

### 5. Bulk Assign Mode Flow (GRID-09)

**Test:** Tap the bulk assign FAB (checklist icon) → checkboxes appear beside employee names → select 2+ employees → tap FAB again → shift picker sheet → select "Siang" → verify all selected employees have "Siang" chip across all 7 days.
**Expected:** Entire flow completes without error; unselected employees are unaffected.
**Why human:** Multi-step stateful UI interaction requires device.

### 6. Auto-Generate Template (GRID-10)

**Test:** Tap auto-generate FAB → template selection dialog → choose "2-shift" or "3-shift" → grid fills with rotated shifts + mandatory libur per employee.
**Expected:** Schedule entries created for all employees across all 7 days per template rotation rule.
**Why human:** Template rotation output and UI result need visual confirmation with real employee data.

---

## Architecture Change Summary

The phase successfully replaced the dual-ListView manual scroll sync architecture with `two_dimensional_scrollables` TableView:

| Removed (old) | Added (new) |
|---------------|------------|
| `_employeeListController`, `_scheduleGridController`, `_horizontalScrollController` | `ScheduleTableView` (StatelessWidget wrapping `TableView.builder`) |
| `_isSyncing` flag + `_setupScrollSync()` method | `DiagonalDragBehavior.free` (platform handles sync) |
| `_buildTable()`, `_buildEmployeeCell()`, `_buildScheduleRow()`, `_buildDayCell()` | `buildCornerCell()`, `buildHeaderCell()`, `buildEmployeeCell()`, `buildShiftCell()` in `schedule_cells.dart` |
| `_buildLegend()`, `_legendChip()` | `ScheduleLegend` widget in `schedule_legend.dart` |
| ~282 lines of rendering/scroll code | 3 new focused widget files (303+161+49 = 513 lines total) |

Screen: 1,194 lines → 943 lines. Net: −251 lines, all rendering code.
All 19 data methods preserved verbatim.

---

*Verified: 2026-03-12*
*Verifier: Claude (gsd-verifier)*
