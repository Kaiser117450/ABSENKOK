---
phase: 58
slug: payroll-matrix-spreadsheet-export
status: approved
shadcn_initialized: false
preset: none
created: 2026-03-27
reviewed_at: 2026-03-27T17:54:14.7283285+08:00
---

# Phase 58 - UI Design Contract

> Visual and interaction contract for Phase 58: Payroll Matrix & Spreadsheet Export.
> Generated via local fallback from Phase 58 context, the current Flutter admin reports surface, and adjacent approved UI contracts from Phases 55 and 56.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (Flutter / Material 3) |
| Preset | not applicable |
| Component library | Material 3 (Flutter built-in) |
| Icon library | Material Icons (Flutter built-in) |
| Font | Plus Jakarta Sans (`google_fonts`) |

Source of truth:
- `lib/core/theme.dart` for palette, typography baseline, button rhythm, card radius, and border usage
- `lib/screens/admin/admin_reports_screen.dart` for current report filters, tab shell, export bar, and recap list integration point
- `lib/screens/admin/widgets/schedule_table_view.dart` for the existing pinned-grid `TableView` pattern
- `.planning/phases/55-schedule-policy-absence-rules/55-UI-SPEC.md` and `.planning/phases/56-server-time-scan-authority/56-UI-SPEC.md` for milestone continuity

Phase 58 stays inside the existing Flutter admin design system. No new design library, dark theme branch, or dashboard visual reset is allowed.

---

## Spacing Scale

Declared values (must be multiples of 4):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Inline time separators, compact tag gaps, icon-to-label spacing |
| sm | 8px | Matrix cell internal gaps, header chip spacing, stacked helper spacing |
| md | 16px | Default card padding, toolbar padding, summary rail padding |
| lg | 24px | Section spacing between filters, export bar, and matrix shell |
| xl | 32px | Major separation between top controls and the payroll matrix |
| 2xl | 48px | Minimum touch-target rhythm for export actions and filter controls |
| 3xl | 64px | Page-level top/bottom breathing room on wide layouts |

Exceptions:
- Existing cards may keep 12px inner padding where `AppCard` continuity already depends on that rhythm.
- Compact matrix day cells may use 12px vertical padding when two-line `masuk/pulang` content plus status tags would otherwise clip.
- All tappable controls must keep a minimum 48x48px touch target, even when the visible chip or icon treatment is tighter.

---

## Typography

Use only 4 sizes and 2 weights in new Phase 58 surfaces.

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| Body | 13sp | w400 | 1.45 |
| Label | 11sp | w700 | 1.25 |
| Heading | 18sp | w700 | 1.2 |
| Display | 24sp | w700 | 1.1 |

Phase 58 hierarchy:

| Element | Size | Weight | Color |
|---------|------|--------|-------|
| Matrix screen title / section heading | 18sp | w700 | `AppColors.textPrimary` |
| Employee name in pinned column | 13sp | w700 | `AppColors.textPrimary` |
| Employee secondary line (`FULLTIME`, `PARTTIME`) | 11sp | w400 | `AppColors.textSecondary` |
| Date header label | 11sp | w700 | `AppColors.textPrimary` |
| Matrix cell time pair (`07:02 / 17:11`) | 13sp | w700 | semantic foreground color |
| Matrix cell fallback label (`Libur`, `Sakit`, `Tidak Hadir`) | 11sp | w700 | semantic foreground color |
| Summary count value | 18sp | w700 | `AppColors.textPrimary` or semantic highlight |
| Summary column label | 11sp | w700 | `AppColors.textSecondary` |
| Export CTA label (`Ekspor Spreadsheet`) | 13sp | w700 | `AppColors.textOnPrimary` |
| Helper / error copy under controls | 13sp | w400 | `AppColors.textSecondary` |

Typography rules:
- Do not introduce a third weight for this phase.
- The payroll matrix is information-dense, so hierarchy must come from placement and semantic color before introducing more text styles.
- Summary numbers are the only display-like treatment on this surface; day cells and labels stay compact.

---

## Color

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `#FFFFFF` | Scaffold background, pinned employee column, main surfaces |
| Secondary (30%) | `#F9FAFB` | Cards, toolbar surfaces, date header strip, summary rail background |
| Accent (10%) | `#DC2626` | Primary payroll export CTA, active tab indicator, active matrix mode emphasis |
| Destructive | `#DC2626` | Reserved only for future destructive actions; none introduced in Phase 58 |

Accent reserved for:
- primary `Ekspor Spreadsheet` CTA on the payroll matrix surface
- the active recap tab underline / active mode state
- keyboard focus ring or active filter emphasis when the matrix view adds a stateful control

Do not use the accent color for every clickable element inside the matrix. Cell colors must communicate payroll semantics, not brand priority.

### Matrix and workbook semantics

| State | Background | Foreground | Usage |
|-------|------------|------------|-------|
| Hadir normal | `#FFFFFF` | `#111827` | Normal day cell with compact `masuk/pulang` pair |
| Terlambat | `#FEF3C7` | `#92400E` | Day cell or workbook cell where late is the primary payroll signal |
| Kurang jam kerja | `#FEE2E2` | `#B91C1C` | Primary red payroll penalty |
| Istirahat berlebih | `#FEE2E2` | `#B91C1C` | Primary red payroll penalty |
| Tidak hadir | `#FEE2E2` | `#B91C1C` | Primary red payroll penalty |
| Belum absen pulang / chain belum lengkap | `#FEE2E2` | `#B91C1C` | Incomplete strict result that must remain payroll-visible |
| Lembur | `#FEF3C7` | `#92400E` | Primary yellow payroll outcome |
| Libur | `#F3F4F6` | `#6B7280` | Non-penalty status label cell |
| Sakit | `#FEF3C7` | `#92400E` | Explicit leave label cell |
| Izin | `#DBEAFE` | `#1E40AF` | Explicit leave label cell |
| Cuti | `#F3E8FF` | `#7C3AED` | Explicit leave label cell |
| Hadir tanpa jadwal | `#ECFEFF` | `#0F766E` | Informational payroll exception |

Workbook rule:
- The `.xlsx` export must reuse the same primary red/yellow status families as the matrix for payroll-significant outcomes.
- Secondary strict signals stay visible as short inline tags inside the same cell and must not change the primary cell fill chosen from `primary_status`.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Primary CTA | `Ekspor Spreadsheet` |
| Empty state heading | `Belum Ada Data Payroll` |
| Empty state body | `Pilih satu outlet dan rentang tanggal untuk menampilkan matriks payroll dan menyiapkan spreadsheet.` |
| Error state | `Spreadsheet belum bisa dibuat. Periksa outlet, rentang tanggal, dan koneksi lalu coba lagi.` |
| Destructive confirmation | `Tidak ada aksi destruktif di fase ini.` |

Additional locked copy:

| Element | Copy |
|---------|------|
| Matrix section title | `Rekap Payroll` |
| Matrix helper | `Pantau hasil harian per karyawan lalu ekspor spreadsheet untuk review gaji.` |
| Employee column heading | `Karyawan` |
| Sticky summary heading | `Ringkasan` |
| Summary labels | `Terlambat`, `Kurang Jam`, `Break Lebih`, `Tidak Hadir`, `Lembur` |
| Workbook sheet name | `Rekap Payroll` |
| Non-time state labels | `Libur`, `Izin`, `Sakit`, `Cuti`, `Tidak Hadir`, `Hadir Tanpa Jadwal` |
| Matrix tag vocabulary | `TLT`, `KJG`, `BRK`, `ABS`, `OT`, `ME` |
| Export in-progress helper | `Menyiapkan spreadsheet payroll...` |
| Export success helper | `Spreadsheet siap dibagikan.` |
| No-outlet guidance | `Pilih satu outlet untuk menghitung payroll matrix.` |

Language rules:
- All user-facing copy stays in Bahasa Indonesia.
- Use payroll-review wording, not disciplinary wording.
- Avoid technical scan jargon such as RPC, GPS, sync payload, or provenance in the primary matrix surface.

Tag rules:
- Tags must stay uppercase and 2-3 letters only.
- `ME` is allowed only for manager exemption visibility and must never read like a penalty.

---

## Visual Hierarchy

Primary focal point:
- The employee-by-date matrix is the first visual anchor. The user's eye should land on the frozen employee column and the first visible date columns immediately after filters are applied.

Secondary anchors:
- The fixed summary rail on the right is the second anchor because it answers payroll-review totals without requiring extra scrolling.
- The `Ekspor Spreadsheet` CTA is the third anchor. It must be visible without overpowering the matrix data.

Hierarchy rules:
- Summary counts should feel important, but they must not visually dominate the day-cell semantics.
- Icon-only controls are not allowed for primary payroll actions. If any icon-only affordance remains, it must include a tooltip or adjacent label.
- The matrix should read as an operations tool, not as a dashboard with oversized decorative numerals.

---

## Component Inventory

### 1. Payroll Matrix Toolbar

Surface:
- `lib/screens/admin/admin_reports_screen.dart` Rekap Harian tab

Purpose:
- Keep outlet/date context, expose the spreadsheet export CTA, and frame the matrix as a payroll review surface.

Required structure:
1. Existing outlet and date-range controls stay first.
2. Existing `Per Scan` / `Rekap Harian` tabs stay intact.
3. On the `Rekap Harian` tab, the export area changes to one primary action: `Ekspor Spreadsheet`.
4. Optional helper or status text may sit below the CTA when exporting or when data is unavailable.

Visual contract:
- Toolbar uses white or `AppColors.surface` surfaces with 16px horizontal padding.
- `Ekspor Spreadsheet` is a filled primary button with icon + text, not a bare text button.
- Legacy `CSV` and `PDF` labels must not sit beside the payroll matrix CTA in the recap context.

### 2. Payroll Matrix Shell

Purpose:
- Present the payroll-ready matrix with the employee roster on the left, day columns in the middle, and sticky summary totals on the right.

Required structure:
1. Frozen employee column
2. Horizontally scrollable date columns
3. Fixed summary rail with exactly 5 columns: `Terlambat`, `Kurang Jam`, `Break Lebih`, `Tidak Hadir`, `Lembur`

Visual contract:
- Header row uses `AppColors.surface` with a 1px `AppColors.border` bottom divider.
- Employee and summary rails remain visible while the day matrix scrolls horizontally.
- Row height stays aligned across employee column, date grid, and summary rail.
- Wide ranges may scroll horizontally, but the matrix shell must never collapse into a stacked card list.

### 3. Payroll Day Cell

Purpose:
- Show one payroll-relevant day outcome compactly without opening a detail screen.

Required content order:
1. Primary line: `masuk / pulang` compact pair when both exist
2. Fallback primary line: explicit state label (`Libur`, `Sakit`, `Izin`, `Tidak Hadir`, etc.) when no normal pair exists
3. Secondary line: compact tags (`TLT`, `KJG`, `BRK`, `ABS`, `OT`, `ME`) only when needed

Behavior:
- Cells are read-only in Phase 58.
- Tapping a cell must not open an edit form, detail drawer, or correction workflow.
- Missing normal time pairs must still show an explicit label; blank cells are not allowed.

Visual contract:
- Minimum cell width stays readable at 92px or wider on large screens.
- Cell fill is determined by `primary_status`.
- Secondary tags remain smaller than the time pair and must not override the primary fill.

### 4. Sticky Summary Rail

Purpose:
- Keep payroll-count totals visible even on wide date ranges.

Required structure:
- One aligned count block per summary type at the far right of every row.
- Summary header row repeats the 5 labels in the same order used by the workbook export.

Visual contract:
- Summary rail uses `AppColors.surface` background distinct from the scrolling date matrix.
- Count values use the `Heading` role when non-zero and `Label`/muted styling when zero.
- Red/problem counts appear before the yellow `Lembur` column.

### 5. Spreadsheet Export Feedback

Purpose:
- Make export state clear without introducing a new screen.

Required states:
- Idle: `Ekspor Spreadsheet`
- Loading: `Menyiapkan spreadsheet payroll...`
- Success: `Spreadsheet siap dibagikan.`
- Error: use the locked error-state copy

Behavior:
- Export feedback should appear inline in the toolbar or via the existing toast pattern, not as a blocking wizard.
- The share flow must hand off a real `.xlsx` file, not a CSV renamed as spreadsheet.

### 6. Workbook Visual Contract

Purpose:
- Keep spreadsheet output visually aligned with the on-screen payroll matrix.

Required workbook structure:
1. Single main sheet named `Rekap Payroll`
2. Frozen top row and frozen employee-identification columns
3. Date columns in chronological order
4. Sticky-summary-equivalent columns at the far right in the same order as the UI

Workbook cell contract:
- Each day cell shows compact `masuk/pulang` text or explicit non-time state label
- Red/yellow primary fills match the matrix semantic table
- Secondary tags remain inline and compact
- GPS, raw coordinates, and low-signal technical provenance are excluded

---

## Interaction Contract

### Matrix interactions
- Applying outlet/date filters refreshes the matrix in place and preserves the current recap tab.
- Horizontal scrolling moves only the date columns; employee identity and summary totals stay visible.
- The matrix remains read-only in this phase.

### Export interactions
- `Ekspor Spreadsheet` is enabled only when one outlet is selected and the date range is valid.
- Export does not require a secondary confirmation dialog.
- Loading and success feedback must stay lightweight and non-blocking.

### Responsive behavior
- On tablet and desktop widths, the matrix shell remains a 3-part layout: employee rail, date grid, summary rail.
- On narrow mobile widths, horizontal scrolling is expected, but the employee rail must remain visible and the summary rail must stay reachable without losing orientation.
- Summary labels may wrap to 2 lines in narrow widths, but count values stay single-line.

---

## Layout Contract

High-level order for the recap payroll surface:

1. Existing AppBar
2. Outlet and date-range controls
3. Existing tab bar
4. Payroll matrix toolbar with `Rekap Payroll` helper and `Ekspor Spreadsheet` CTA
5. Payroll matrix shell
   - frozen employee rail
   - date grid
   - sticky summary rail

Do not place the summary counts below the grid or hide them behind a separate modal. They are part of the primary review surface.

Workbook layout contract:
- Employee identity columns come first
- Date columns occupy the center
- Summary columns close the sheet on the far right
- The workbook stays single-sheet and must feel like a spreadsheet version of the on-screen matrix, not a separate audit report

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| Flutter / Material built-ins | `TableView`, `TabBar`, `FilledButton`, `TextButton`, `Icon`, `Card`, `Tooltip` | not required |
| Existing pubspec packages | `google_fonts`, `share_plus`, `two_dimensional_scrollables` | already in repo |
| Third-party UI registries | none | not applicable |

No shadcn, Radix, or third-party component registry work is allowed in this phase because the project is Flutter and already has an established Material-based design system.

---

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS
- [x] Dimension 2 Visuals: PASS
- [x] Dimension 3 Color: PASS
- [x] Dimension 4 Typography: PASS
- [x] Dimension 5 Spacing: PASS
- [x] Dimension 6 Registry Safety: PASS

**Approval:** approved 2026-03-27
