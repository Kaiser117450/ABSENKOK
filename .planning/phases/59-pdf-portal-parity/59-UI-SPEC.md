---
phase: 59
slug: pdf-portal-parity
status: approved
shadcn_initialized: false
preset: none
created: 2026-03-28
reviewed_at: 2026-03-28T15:32:49.8990493+08:00
---

# Phase 59 - UI Design Contract

> Visual and interaction contract for Phase 59: PDF & Portal Parity.
> Generated from Phase 59 context/research, the approved Phase 55/58 UI-SPECs, the current Flutter admin/PDF stack, and the current Astro portal shell.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (`Flutter Material 3` + existing `Astro/Tailwind` portal shell) |
| Preset | not applicable |
| Component library | Flutter `Material 3` + custom `AppCard` / `AppEmptyState`; Astro server-rendered card layout with Tailwind utility classes |
| Icon library | Material Icons in Flutter/PDF, inline SVG stroke icons in Astro portal |
| Font | Plus Jakarta Sans for Flutter/PDF, Inter for the existing portal shell |

Source of truth:
- `.planning/phases/59-pdf-portal-parity/59-CONTEXT.md` locked D-01 through D-13 for band-first portal framing and matrix-first payroll PDF structure
- `.planning/phases/59-pdf-portal-parity/59-RESEARCH.md` for the shared-matrix parity direction and the portal/PDF gap analysis
- [theme.dart](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/core/theme.dart), [payroll_matrix_semantics.dart](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/services/payroll_matrix_semantics.dart), and [admin_reports_screen.dart](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/screens/admin/admin_reports_screen.dart)
- [global.css](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/src/styles/global.css), [PortalLayout.astro](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/src/layouts/PortalLayout.astro), [PortalStatePanel.astro](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/src/components/portal/PortalStatePanel.astro), [PortalScheduleSection.astro](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/src/components/portal/PortalScheduleSection.astro), and [PortalAttendanceHistorySection.astro](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceHistorySection.astro)
- `.planning/phases/58-payroll-matrix-spreadsheet-export/58-UI-SPEC.md` and `.planning/phases/55-schedule-policy-absence-rules/55-UI-SPEC.md` for milestone continuity

Phase 59 stays inside the existing design systems. No shadcn, no new web component library, no portal shell rebrand, and no visual reset of the admin report screen are allowed.

---

## Spacing Scale

Declared values (must be multiples of 4):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Inline tag gaps, legend dot spacing, slash separators inside compact labels |
| sm | 8px | Chip spacing, portal metric-row gaps, matrix tag spacing, PDF legend gaps |
| md | 16px | Default card padding, portal card internals, toolbar padding, summary panel padding |
| lg | 24px | Section spacing between portal blocks, export toolbar and matrix shell, PDF summary clusters |
| xl | 32px | Major separation between filters/header chrome and the parity surfaces |
| 2xl | 48px | Summary-to-matrix separation on the PDF first page and minimum action rhythm on wide layouts |
| 3xl | 64px | Page-level breathing room on wide desktop surfaces and PDF cover-like summary spacing |

Exceptions:
- Existing 12px radius and 12px compact padding from `AppCard` and current portal cards stay in place for continuity.
- Matrix and PDF tables may keep 0.5px to 1px hairline borders for dense payroll data.
- Portal icon-only or tab-like controls must keep a minimum 44x44px hit area; Flutter admin controls stay at a minimum 48x48px hit area.

Spacing source:
- 4/8/16/24/32/48/64 scale is inherited from the approved Phase 58 contract.
- The 12px card rhythm is inherited from [app_card.dart](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/widgets/app_card.dart) and current portal cards.

---

## Typography

Use only 4 sizes and 2 weights in new Phase 59 surfaces.

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| Body | 13px | w400 | 1.45 |
| Label | 11px | w700 | 1.25 |
| Heading | 18px | w700 | 1.2 |
| Display | 24px | w700 | 1.1 |

Phase 59 hierarchy:

| Element | Size | Weight | Color |
|---------|------|--------|-------|
| Portal band label (`Pagi`, `Siang`, `Sore`) | 18px | w700 | `text-gray-900` or semantic foreground |
| Portal required-hours and progress lines | 13px | w400 | `text-gray-600` / semantic foreground |
| Portal outcome chip label | 11px | w700 | semantic foreground |
| Portal helper copy | 13px | w400 | `text-gray-500` |
| Payroll export section title | 18px | w700 | `AppColors.textPrimary` |
| PDF summary metric value | 24px | w700 | semantic highlight or `AppColors.textPrimary` |
| PDF matrix primary cell label | 11px | w700 | semantic foreground |
| PDF matrix short tag / legend label | 11px | w700 | semantic foreground |
| Inline export status copy | 13px | w400 | `AppColors.textSecondary` |

Typography rules:
- Flutter/PDF keep Plus Jakarta Sans from [theme.dart](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/core/theme.dart); the portal shell keeps Inter from [global.css](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/src/styles/global.css).
- Do not introduce a third font family or a third font weight.
- Exact schedule clock ranges are removed from primary portal hierarchy, so typography emphasis moves to band, target, and progress instead.
- PDF print compaction must preserve this four-size hierarchy; short tags and legend labels reuse the 11px label role instead of adding a print-only type size.

---

## Color

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `#FFFFFF` | Portal cards, admin recap surfaces, matrix body, PDF paper |
| Secondary (30%) | `#F9FAFB` | Page canvas, summary panels, empty states, neutral shells |
| Accent (10%) | `#DC2626` | Primary `Ekspor PDF Payroll` CTA, current-day marker, summary-page keyline, active export emphasis |
| Destructive | `#B91C1C` | Destructive confirmations only; none introduced in this phase |

Accent reserved for:
- primary `Ekspor PDF Payroll` action on the recap tab
- current-day emphasis inside portal parity cards
- one compact keyline or title accent on the PDF summary page
- explicit export-in-progress emphasis when inline status is shown

Do not use the accent color for strict payroll outcomes. Strict outcomes must reuse the shipped payroll matrix semantics.

### Strict parity semantics

| State | Background | Foreground | Usage |
|-------|------------|------------|-------|
| Hadir normal | `#FFFFFF` | `#111827` | Completed day with balanced work time |
| Terlambat | `#FEF3C7` | `#92400E` | Final late outcome across portal, admin, spreadsheet, and PDF |
| Kurang jam kerja | `#FEE2E2` | `#B91C1C` | Final red payroll penalty |
| Istirahat berlebih | `#FEE2E2` | `#B91C1C` | Final red payroll penalty |
| Tidak hadir | `#FEE2E2` | `#B91C1C` | Final red payroll penalty |
| Belum absen pulang (closed day) | `#FEE2E2` | `#B91C1C` | Final incomplete day once the logical day is closed |
| Lembur | `#FEF3C7` | `#92400E` | Final yellow payroll outcome |
| Manager exempt | `#F8FAFC` | `#334155` | Visible but non-penalty manager outcome |
| Hadir tanpa jadwal | `#ECFEFF` | `#0F766E` | Informational attendance exception |
| Belum masuk / placeholder | `#F3F4F6` | `#6B7280` | Neutral day with no final payroll outcome yet |
| Sedang berjalan (portal only) | `#F9FAFB` | `#374151` | Current-day progress card before a final strict result is locked |

Tone rules:
- Final payroll outcomes must match `PayrollMatrixSemantics` exactly across admin recap, spreadsheet export, PDF export, and closed-day portal history.
- Portal current-day states may stay neutral and calm until the logical day closes.
- Exact shift clocks are never allowed to re-enter the primary hierarchy as a substitute for semantic color and explicit outcome labels.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Primary CTA | `Ekspor PDF Payroll` |
| Secondary CTA | `Ekspor Spreadsheet` |
| Portal empty state heading | `Belum ada jadwal` |
| Portal empty state body | `Jadwal minggu ini belum diterbitkan. Cek kembali setelah admin menerbitkan jadwal.` |
| Payroll empty state heading | `Belum ada data payroll` |
| Payroll empty state body | `Pilih outlet dan rentang tanggal untuk menampilkan rekap payroll lalu buat PDF.` |
| Portal error state | `Data belum bisa dimuat. Muat ulang halaman. Jika tetap gagal, hubungi admin.` |
| Export error state | `PDF payroll belum bisa dibuat. Coba lagi. Jika masih gagal, gunakan spreadsheet lalu laporkan ke admin.` |
| Destructive confirmation | `Tidak ada aksi destruktif baru di fase ini.` |

### Portal helper copy by outcome

| Outcome | Supporting Copy |
|---------|-----------------|
| `Terlambat` | `Jam masuk hari ini tercatat melewati batas shift.` |
| `Kurang jam kerja` | `Jam kerja yang tercatat masih di bawah target kontrak.` |
| `Istirahat berlebih` | `Total istirahat hari ini melewati batas yang diizinkan.` |
| `Lembur` | `Jam kerja hari ini melebihi target kontrak.` |
| `Tidak hadir` | `Tidak ada scan pada hari kerja yang sudah selesai.` |
| `Manager exempt` | `Kehadiran tetap tercatat, tetapi posisi manajerial tidak dikenai penalti merah.` |
| `Sedang berjalan` | `Hari kerja masih berjalan. Target dan sisa waktu akan diperbarui sampai chain selesai.` |
| `Belum masuk` | `Hari kerja hari ini belum memiliki scan masuk.` |

Additional locked copy:

| Element | Copy |
|---------|------|
| Portal metric labels | `Wajib`, `Tercatat`, `Sudah berjalan`, `Sisa`, `Lebih`, `Kurang` |
| PDF summary title | `Rekap Payroll PDF` |
| PDF matrix legend labels | `TLT`, `KJG`, `BRK`, `ABS`, `OT`, `ME` |
| Export loading helper | `Menyiapkan PDF payroll...` |
| Export success helper | `PDF payroll siap dibagikan.` |
| Compatibility banner title | `Mode kompatibilitas aktif` |
| Compatibility banner body | `Sebagian hari payroll dihitung dari log absensi dan kontrak karena jadwal belum tersedia.` |

Language rules:
- All user-facing copy stays in Bahasa Indonesia.
- Portal copy must stay calm and employee-facing even when the strict outcome is explicit.
- PDF/admin copy stays payroll-review oriented and must not introduce raw technical terms such as GPS, queue order, sync metadata, RPC, or capture mode.

Copy sources:
- Outcome names come from `.planning/phases/59-pdf-portal-parity/59-CONTEXT.md` D-05 through D-07.
- Empty/error tone inherits the current patterns in [PortalStatePanel.astro](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/src/components/portal/PortalStatePanel.astro), [app_empty_state.dart](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/widgets/app_empty_state.dart), and [admin_reports_screen.dart](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/screens/admin/admin_reports_screen.dart).

---

## Visual Hierarchy

### Portal surfaces

Primary order inside every parity card:
1. band label (`Pagi`, `Siang`, `Sore`) or explicit leave/day-off label
2. day context (`Hari ini` pill or logical date)
3. required-hours target (`Wajib 10j`, `Wajib 9j`)
4. progress or comparison line (`Sudah berjalan`, `Sisa`, `Tercatat`, `Lebih`, `Kurang`)
5. strict outcome chip
6. calm helper copy
7. tertiary evidence rows such as outlet name, attendance timestamps, or notes

Rules:
- The band label is the primary visual anchor; the `Hari ini` pill is secondary orientation only.
- Exact schedule ranges are removed from the main card body.
- Actual attendance timestamps may remain as tertiary evidence only on recap/history cards.
- Current-day emphasis comes from a compact pill and border treatment, not a full accent-colored card.

### PDF surfaces

Primary order:
1. summary page heading and outlet/date context
2. compatibility banner when fallback rows exist
3. compact summary metrics in the same order as the spreadsheet counts
4. legend for `TLT`, `KJG`, `BRK`, `ABS`, `OT`, `ME`
5. matrix pages as the canonical recap body

Rules:
- The matrix, not the summary, is the core payroll artifact.
- Tags stay secondary to the main cell label.
- Decorative hero numerals or poster-like cover pages are not allowed.

---

## Component Inventory

### 1. Portal Today Schedule Card

Files:
- [PortalScheduleSection.astro](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/src/components/portal/PortalScheduleSection.astro)
- [schedule.ts](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/src/lib/portal/schedule.ts)

Purpose:
- Replace the clock-first today card with a band-first, target-first, progress-aware card.

Required content order:
1. band label or leave/day-off label
2. `Hari ini` pill
3. outlet name only as tertiary metadata
4. `Wajib {Xj}`
5. progress block
   - active day: `Sudah berjalan {Xj Ym}` + `Sisa {Xj Ym}`
   - completed day: `Tercatat {Xj Ym}` + `Lebih` or `Kurang {Xj Ym} dari target`
6. strict outcome chip when a final outcome exists
7. calm supporting copy

Visual contract:
- White or neutral card surface, 12px radius, 16px padding.
- Current-day emphasis uses a subtle border and pill, not a full-color card fill.
- Start/end schedule ranges must not appear anywhere in the card body.
- Do not add expand/collapse, drilldown drawers, or correction-request buttons.

### 2. Portal Week Assignment Row

Files:
- [PortalScheduleSection.astro](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/src/components/portal/PortalScheduleSection.astro)
- [schedule.ts](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/src/lib/portal/schedule.ts)

Purpose:
- Keep upcoming assignments scannable without reverting to shift-clock UI.

Required structure:
1. day label column
2. band label or explicit leave/day-off label
3. required-hours mini line
4. outlet name tertiary line when present

Rules:
- Future rows show band + required hours only; they do not fabricate progress.
- Exact schedule ranges are not shown on week rows.
- Icon-only status badges are not allowed as the primary state communication.

### 3. Portal Attendance History Card

Files:
- [PortalAttendanceHistorySection.astro](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/src/components/portal/PortalAttendanceHistorySection.astro)
- [attendance-recap.ts](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absenkok-website/src/lib/portal/attendance-recap.ts)

Purpose:
- Show the same strict outcome as admin/spreadsheet/PDF while keeping the portal tone calm.

Required structure:
1. logical date indicator
2. strict outcome chip
3. band + required-hours line
4. worked-versus-target line
5. actual attendance timestamps as tertiary evidence
6. calm helper copy
7. notes if present

Rules:
- Do not show schedule clock ranges.
- Short tags like `TLT` or `KJG` are PDF/spreadsheet-only and must not replace explicit labels in the portal.
- Prior-day follow-up gaps may show a follow-up chip; current-day states must remain informational.

### 4. Admin Recap Export Bar

Files:
- [admin_reports_screen.dart](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/screens/admin/admin_reports_screen.dart)

Purpose:
- Add the payroll-facing PDF action without removing the shipped spreadsheet action.

Required structure:
1. title `Rekap Payroll`
2. existing helper copy
3. compatibility banner when fallback rows exist
4. primary filled button `Ekspor PDF Payroll`
5. secondary outlined button `Ekspor Spreadsheet`
6. inline export status message below or beside the actions

Rules:
- Recap-tab exports must be payroll-facing only.
- Legacy per-scan PDF and CSV actions remain outside the recap tab.
- Buttons may wrap on narrow widths but must preserve the order: PDF first, spreadsheet second.

### 5. Payroll PDF Summary Page

Files:
- [pdf_service.dart](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/services/pdf_service.dart)
- [payroll_matrix_semantics.dart](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/services/payroll_matrix_semantics.dart)

Purpose:
- Give payroll operators quick orientation before the matrix pages.

Required content:
1. report title and outlet/date range
2. compatibility banner when fallback rows are present
3. exactly 5 summary metrics in this order:
   - `Terlambat`
   - `Kurang Jam`
   - `Break Lebih`
   - `Tidak Hadir`
   - `Lembur`
4. one compact legend row for `TLT`, `KJG`, `BRK`, `ABS`, `OT`, `ME`
5. short note that matrix colors follow the payroll recap semantics

Visual contract:
- Keep the page compact; it is a summary, not a dashboard poster.
- Use the same semantic colors already defined by `PayrollMatrixSemantics`.
- Do not include GPS, queue, sync, or raw scan metadata anywhere on the page.

### 6. Payroll PDF Matrix Pages

Files:
- [pdf_service.dart](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/services/pdf_service.dart)
- [payroll_matrix_semantics.dart](/abs/path/C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/lib/services/payroll_matrix_semantics.dart)

Purpose:
- Mirror the spreadsheet-style employee/date matrix as the canonical PDF recap body.

Required structure:
1. landscape matrix page
2. employee identity columns first
3. date columns in chronological order
4. summary columns on the far right in the same order as the summary page

Cell contract:
- Primary line is either `masuk / pulang` or one explicit state label.
- Secondary line contains only compact short tags.
- Max 2 text lines inside a day cell.
- Cell fill always comes from the strict primary status, not from secondary tags.

Prohibited content:
- GPS coordinates
- latitude/longitude
- queue order
- sync or capture metadata
- raw technical field names
- legacy row-per-day audit table as the main payroll body

---

## Interaction Contract

### Portal interactions
- Portal parity cards remain read-only.
- No edit, correction-request, or approval workflow is introduced in this phase.
- Retry behavior uses the existing `PortalStatePanel` pattern; do not introduce modal error flows.
- When no schedule or recap data exists, show a single empty-state card, not a blank section.

### Export interactions
- `Ekspor PDF Payroll` is enabled only when outlet and date range are valid and the payroll dataset is non-empty.
- PDF creation is non-blocking and keeps the user on the same recap tab.
- Inline export status follows this sequence: idle -> loading -> success or error.
- Spreadsheet export remains available as a parallel payroll artifact; PDF does not replace it.

### Parity rule
- For the same logical workday, portal, admin matrix, spreadsheet, and PDF must show the same primary outcome and the same severity family.
- The portal may use explicit human-readable labels where the spreadsheet/PDF use short tags, but the meaning must stay identical.

---

## Layout Contract

### Portal home and attendance pages

1. existing portal shell header/nav
2. existing employee greeting/identity block
3. today schedule card
4. week assignment list
5. attendance history list on the attendance page

Rules:
- Keep the portal one-column and phone-first.
- Do not replace the card layout with a dense table.
- Do not insert new portal tabs or side panels for this phase.

### Admin recap tab

1. existing filter controls
2. existing tab bar
3. compatibility banner when needed
4. export bar with PDF primary and spreadsheet secondary
5. existing payroll matrix shell

### PDF report flow

1. summary page
2. matrix pages

Rules:
- The legacy daily row table is not allowed as the main payroll PDF body.
- The legend lives on the summary page; the matrix pages stay focused on the table body.

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| Flutter / Material built-ins | `AppCard`, `AppEmptyState`, `TabBar`, `FilledButton`, `OutlinedButton`, `Icon`, `TableView` | not required |
| Existing repo packages | `google_fonts`, `pdf`, `share_plus`, `two_dimensional_scrollables`, `@fontsource/inter`, Tailwind utility classes | already in repo |
| Third-party UI registries | none | not applicable |

shadcn gate:
- not applicable
- no `components.json` exists in the active Flutter repo
- the affected web surface is an existing Astro/Tailwind implementation, not a new React/shadcn surface

---

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS
- [x] Dimension 2 Visuals: PASS
- [x] Dimension 3 Color: PASS
- [x] Dimension 4 Typography: PASS
- [x] Dimension 5 Spacing: PASS
- [x] Dimension 6 Registry Safety: PASS

**Approval:** approved 2026-03-28
