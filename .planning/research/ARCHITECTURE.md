# Architecture Patterns — v3.0 Schedule Grid + Landing Website

**Domain:** NFC attendance kiosk (Flutter) + Marketing website (Astro.js)
**Researched:** 2026-03-12

## Part 1: Schedule Grid Architecture

### Recommended Architecture

```
┌─────────────────────────────────────────────────────┐
│ ShiftSchedulerScreen (ConsumerStatefulWidget)        │
│                                                      │
│  ┌──────────────┐  ┌─────────────────────────────┐  │
│  │ AppBar        │  │ State (unchanged):           │  │
│  │ (actions)     │  │  _employees, _currentSchedule│  │
│  └──────────────┘  │  _sakitIzinMap, _timeOffMap  │  │
│                     │  _leaveBalance, _startDate   │  │
│  ┌──────────────┐  └─────────────────────────────┘  │
│  │ Header       │                                    │
│  │ (week nav)   │  ┌─────────────────────────────┐  │
│  └──────────────┘  │ Data Layer (KEEP AS-IS):     │  │
│                     │  Supabase CRUD               │  │
│  ┌──────────────┐  │  ScheduleSQLiteService       │  │
│  │ Legend        │  │  PdfService export           │  │
│  │ (shift chips)│  └─────────────────────────────┘  │
│  └──────────────┘                                    │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │ TableView (NEW - two_dimensional_scrollables)  │  │
│  │                                                 │  │
│  │  ┌─────────┬──────┬──────┬──────┬──────────┐  │  │
│  │  │KARYAWAN │ Sen  │ Sel  │ Rab  │ ...      │  │  │
│  │  │ (pinned)│      │      │      │          │  │  │
│  │  ├─────────┼──────┼──────┼──────┼──────────┤  │  │
│  │  │ Ahmad   │[Pagi]│[Sore]│  ∅   │[Libur]   │  │  │
│  │  │ Budi    │[Sore]│[Pagi]│[Pagi]│  ∅       │  │  │
│  │  │ Citra   │ SAKIT│[Siang│[Sore]│[Pagi]    │  │  │
│  │  └─────────┴──────┴──────┴──────┴──────────┘  │  │
│  │                                                 │  │
│  │  pinnedRowCount: 1 (header)                     │  │
│  │  pinnedColumnCount: 1 (employee names)          │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  ┌──────────┐  ┌──────────┐                         │
│  │ Bulk FAB │  │ Auto FAB │                         │
│  └──────────┘  └──────────┘                         │
└─────────────────────────────────────────────────────┘
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `ShiftSchedulerScreen` | Top-level orchestrator, state holder | All child widgets, AppProvider |
| `_buildTableView()` | Renders `TableView` with pinned rows/cols | Cell builders |
| `_buildHeaderCell(day)` | Day name + date in header row | None (pure display) |
| `_buildEmployeeCell(emp)` | Employee name + leave badge + bulk checkbox | Bulk select state |
| `_buildShiftCell(emp, day)` | Shift chip or empty cell, tap handler | `_addShift()`, `_removeEntry()` |
| `_showShiftPicker()` | Bottom sheet for shift selection | `_addShift()` callback |
| Data layer (UNCHANGED) | `_loadData()`, `_saveSchedule()`, `_loadScheduleFromSupabase()` | Supabase, SQLiteService |

### Data Flow

```
User taps empty cell
  → _showShiftPicker(emp, date)
    → showModalBottomSheet with Pagi/Siang/Sore/Libur options
      → User selects "Pagi"
        → _addShift(emp, date, ShiftSlot.pagi())
          → setState: remove old entry, add new ScheduleEntry
            → TableView rebuilds affected cell
              → AnimatedSwitcher: empty → shift chip with pop-in

User taps "Save" (unchanged)
  → _saveSchedule()
    → Supabase INSERT schedule + entries
      → SQLite write-through cache
        → setState: _hasUnsavedChanges = false
```

### Key Refactoring Pattern

**Before (current):** 1,123 lines in one widget
```
_buildTable() → Row([
  Container(width: 110, child: Column([   // employee column
    ListView.builder(controller: _employeeListController, ...)
  ])),
  Expanded(child: SingleChildScrollView(   // horizontal scroll
    child: Column([
      Row(children: days.map(header)),     // day headers
      ListView.builder(controller: _scheduleGridController, ...)
    ])
  ))
])
```

**After (redesign):** Extract cell builders, replace with TableView
```
TableView(
  pinnedRowCount: 1,
  pinnedColumnCount: 1,
  columnCount: 8,
  rowCount: _employees.length + 1,
  cellBuilder: (context, vicinity) {
    if (vicinity.row == 0 && vicinity.column == 0) return _cornerCell();
    if (vicinity.row == 0) return _headerCell(vicinity.column - 1);
    if (vicinity.column == 0) return _employeeCell(vicinity.row - 1);
    return _shiftCell(vicinity.row - 1, vicinity.column - 1);
  },
  columnBuilder: _columnBuilder,
  rowBuilder: _rowBuilder,
)
```

**Files to extract from the monolith:**

| New File | Contents | Lines (est.) |
|----------|----------|--------------|
| `schedule_grid_widget.dart` | `TableView` wrapper + cell builders | ~200 |
| `schedule_cell_widgets.dart` | Header, employee, shift cell widgets | ~150 |
| `shift_scheduler_screen.dart` | State, data loading, save (slimmed) | ~500 |

Total: ~850 lines (down from 1,123) with much better separation of concerns.

## Patterns to Follow

### Pattern 1: TableView Cell Builder Dispatch

**What:** Single `cellBuilder` callback that dispatches to typed cell widgets
**When:** Always — this is the core rendering pattern for `two_dimensional_scrollables`

```dart
TableViewCell _buildCell(BuildContext context, TableVicinity vicinity) {
  // Corner cell (row 0, col 0)
  if (vicinity.row == 0 && vicinity.column == 0) {
    return TableViewCell(
      child: Container(
        color: AppColors.surface,
        alignment: Alignment.center,
        child: Text('KARYAWAN', style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w800)),
      ),
    );
  }
  // Header row
  if (vicinity.row == 0) {
    final dayIndex = vicinity.column - 1;
    final date = _startDate.add(Duration(days: dayIndex));
    return _buildHeaderCell(date);
  }
  // Employee column
  if (vicinity.column == 0) {
    final empIndex = vicinity.row - 1;
    return _buildEmployeeCell(_employees[empIndex]);
  }
  // Shift cells
  final empIndex = vicinity.row - 1;
  final dayIndex = vicinity.column - 1;
  final date = _startDate.add(Duration(days: dayIndex));
  return _buildShiftCell(_employees[empIndex], date);
}
```

### Pattern 2: Animated Shift Assignment

**What:** Smooth visual feedback when shift is assigned to a cell
**When:** Every cell state change (empty → assigned, assigned → different, assigned → cleared)

```dart
Widget _buildShiftChip(ScheduleEntry? entry) {
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    transitionBuilder: (child, animation) => ScaleTransition(
      scale: animation,
      child: child,
    ),
    child: entry == null
      ? Container(
          key: const ValueKey('empty'),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.add, size: 14, color: Colors.grey),
        )
      : Container(
          key: ValueKey(entry.shift.name),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: entry.shift.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: entry.shift.color.withOpacity(0.3)),
          ),
          child: Text(entry.shift.name,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: entry.shift.color)),
        ),
  );
}
```

### Pattern 3: Preserve Data Layer Interface

**What:** The data layer (_loadData, _saveSchedule, _loadScheduleFromSupabase, etc.) stays EXACTLY as-is
**When:** During the entire redesign — never touch data methods

**Why:** The Supabase ↔ SQLite sync pattern is production-proven at 4 outlets. The redesign is rendering-only.

```dart
// RULE: These methods are copy-pasted unchanged into the new file:
// _loadData(), _loadScheduleFromSupabase(), _loadSakitIzinData(),
// _loadTimeOffRequests(), _loadCarryOverBalance(),
// _addShift(), _removeEntry(), _bulkAssign(), _generateAutoSchedule(),
// _saveSchedule(), _exportToPdf()
```

---

## Part 2: Astro.js Website Architecture

### Recommended Architecture

```
┌─────────────────────────────────────────────┐
│ index.astro (page)                          │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ BaseLayout.astro (layout)              │  │
│  │  <head> meta, fonts, global CSS        │  │
│  │  <body>                                │  │
│  │    ┌──────────────────────────────┐    │  │
│  │    │ Header.astro (nav + logo)    │    │  │
│  │    ├──────────────────────────────┤    │  │
│  │    │ Hero.astro (headline + CTA)  │    │  │
│  │    ├──────────────────────────────┤    │  │
│  │    │ Features.astro (3-4 cards)   │    │  │
│  │    ├──────────────────────────────┤    │  │
│  │    │ Download.astro (APK button)  │    │  │
│  │    ├──────────────────────────────┤    │  │
│  │    │ Footer.astro + Watermark     │    │  │
│  │    └──────────────────────────────┘    │  │
│  │  </body>                               │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Zero JavaScript shipped (100% static HTML)  │
└─────────────────────────────────────────────┘
```

### Astro Component Pattern

**What:** Pure `.astro` components with Tailwind utility classes. No framework islands (React/Vue/Svelte) needed.

```astro
---
// Hero.astro — frontmatter (runs at build time, not shipped to client)
import { Image } from 'astro:assets';
import heroMockup from '../assets/images/hero-mockup.png';
---

<section class="relative overflow-hidden bg-white py-20 lg:py-32">
  <div class="mx-auto max-w-7xl px-6 lg:px-8">
    <div class="grid grid-cols-1 gap-16 lg:grid-cols-2 lg:items-center">
      <div>
        <h1 class="text-4xl font-bold tracking-tight text-gray-900 sm:text-6xl">
          Absensi NFC untuk Restoran Modern
        </h1>
        <p class="mt-6 text-lg leading-8 text-gray-600">
          Tap kartu, hadir tercatat. ABSENKOK mengelola kehadiran karyawan
          dengan NFC, jadwal shift, dan laporan real-time.
        </p>
        <a href="https://github.com/user/repo/releases/latest"
           class="mt-8 inline-block rounded-full bg-brand-primary px-8 py-3
                  text-white font-semibold hover:bg-brand-dark transition-colors">
          Download APK
        </a>
      </div>
      <Image src={heroMockup} alt="ABSENKOK app screenshot"
             class="rounded-2xl shadow-2xl" width={600} />
    </div>
  </div>
</section>
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Touching the Data Layer During Grid Redesign
**What:** Modifying `_loadData()`, `_saveSchedule()`, `_loadScheduleFromSupabase()`, or any Supabase/SQLite code
**Why bad:** Production data flow serving 4 outlets. Any bug here = broken schedules.
**Instead:** Treat data methods as a black-box API. Copy them unchanged. Only modify rendering code.

### Anti-Pattern 2: Adding JavaScript Framework Islands to Website
**What:** Installing React/Svelte for "a small interactive component"
**Why bad:** Ships framework runtime to client. Breaks zero-JS promise. Slower page load.
**Instead:** Use CSS animations, Tailwind utilities, and tiny inline `<script>` tags for scroll-triggered effects (e.g., `IntersectionObserver` in <10 lines).

### Anti-Pattern 3: Building the Grid Cell Builder as One Giant Switch
**What:** 200-line `cellBuilder` with nested if/else for all cell types
**Why bad:** Unmaintainable. Same problem as the current 1,123-line file.
**Instead:** Dispatch to typed cell widget methods: `_cornerCell()`, `_headerCell()`, `_employeeCell()`, `_shiftCell()`. Each is <30 lines.

### Anti-Pattern 4: Dynamic Content on Website
**What:** Fetching Supabase data at build time, pulling live employee counts, etc.
**Why bad:** Couples website to backend. Build failures if Supabase is down. Leaks internal data.
**Instead:** Hardcode all marketing copy. The website is a brochure, not a dashboard.

## Scalability Considerations

| Concern | Current (14 emp) | 50 employees | 200 employees |
|---------|-------------------|--------------|---------------|
| Grid rendering | 14×7=98 cells, trivial | 50×7=350 cells, still fine | 200×7=1400 cells, `TableView` handles this via virtualization |
| Scroll performance | No issue | No issue | `TableView` only renders visible cells — designed for this |
| Data loading | Single Supabase query | Pagination may help | Definitely paginate or filter by outlet |
| PDF export | Single page | Multi-page PDF | Needs section headers per shift |
| Website traffic | Static files, CDN | Same | Same — Vercel CDN scales infinitely for static |
