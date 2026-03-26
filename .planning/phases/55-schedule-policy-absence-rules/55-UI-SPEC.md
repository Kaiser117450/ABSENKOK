---
phase: 55
slug: schedule-policy-absence-rules
status: approved
reviewed_at: 2026-03-26
shadcn_initialized: false
preset: none
created: 2026-03-26
---

# Phase 55 - UI Design Contract

> Visual and interaction contract for Phase 55: Schedule Policy & Absence Rules.
> Generated via local fallback after the UI subagent shut down on Windows. Verified against the existing Flutter theme, Phase 55 context/research, and the current plan set.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (Flutter / Material 3) |
| Preset | not applicable |
| Component library | Material 3 (Flutter built-in) |
| Icon library | Material Icons (Flutter built-in) |
| Font | Plus Jakarta Sans (`google_fonts`) |

**Source of truth:** `lib/core/theme.dart` (`AppColors`, `buildAppTheme()`), plus the current scheduler and admin report widgets already in the repo.

---

## Spacing Scale

Declared values (must be multiples of 4):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Icon gaps inside compact chips, inline label separators |
| sm | 8px | Filter chip spacing, compact row gaps, schedule hint spacing |
| md | 16px | Default card padding, horizontal page padding, modal content spacing |
| lg | 24px | Section padding, card-to-card vertical rhythm |
| xl | 32px | Major breaks between scheduler header, grid, and recap sections |
| 2xl | 48px | Large dialog/header separation and minimum touch-target rhythm |
| 3xl | 64px | Not used in this phase |

Exceptions:
- Existing schedule chips may keep 12px inner horizontal padding and 6px corner radius for continuity with the current grid.
- Existing scheduler header cards may use 12px internal padding where they already match the theme's card rhythm.
- All interactive controls must keep a minimum 48x48px touch target.

---

## Typography

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| Body | 13sp | w400 | 1.45 |
| Label | 11sp | w600 | 1.25 |
| Heading | 18sp | w700 | 1.2 |
| Display | 20sp | w700 | 1.1 |

Phase 55-specific hierarchy:

| Element | Size | Weight | Color |
|---------|------|--------|-------|
| Scheduler card title (`Aturan Jadwal Minggu Ini`) | 14sp | w700 | `AppColors.textPrimary` |
| Grid chip primary (`Pagi - 10j`) | 11sp | w700 | band-specific foreground color |
| Grid chip secondary hint (`07:00 batas telat`) | 9sp | w600 | darker semantic tone within the same chip family |
| Bulk review title (`Tinjau Penugasan`) | 16sp | w700 | `AppColors.textPrimary` |
| Recap filter chip label | 12sp | w600 | `AppColors.textPrimary` or semantic selected color |
| Policy badge label (`Tidak hadir`, `Break-first`) | 11sp | w700 | semantic foreground color |
| Reason copy under recap badge | 11sp | w400 | `AppColors.textSecondary` |

Do not introduce a new font family, condensed display type, or oversized dashboard numerals for this phase. This is an additive admin workflow update inside an established Flutter design system.

---

## Color

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `#FFFFFF` | App background, scheduler scaffold, card surfaces |
| Secondary (30%) | `#F9FAFB` | Cards, section surfaces, filter containers |
| Accent (10%) | `#DC2626` | Primary CTA, selected high-priority filter state, AppBar continuity |
| Destructive | `#DC2626` | True danger states only: destructive confirmations and `Tidak hadir` follow-up emphasis |

Accent reserved for:
- primary confirmation CTA in the bulk review step
- the scheduler AppBar and save affordances already using the repo's theme
- the selected state for the most severe recap follow-up chip only when it is the active filter

Do not use the accent color for all interactive elements. Phase 55 needs stronger semantic separation than "everything red".

### Semantic schedule colors

| State | Background | Foreground | Usage |
|-------|------------|------------|-------|
| Pagi | `#DBEAFE` | `#1E40AF` | Morning band chip / hint surface |
| Siang | `#FEF3C7` | `#92400E` | Midday band chip / hint surface |
| Sore | `#FFEDD5` | `#C2410C` | Evening band chip / hint surface |
| Libur | `#FEE2E2` | `#991B1B` | Scheduled day-off chip |
| Sakit | `#FEF3C7` | `#92400E` | Leave override badge |
| Izin | `#DBEAFE` | `#1E40AF` | Leave override badge |
| Cuti | `#F3E8FF` | `#7C3AED` | Approved leave badge, distinct from `Libur` |
| Belum Masuk | `#FEF9C3` | `#854D0E` | Current-day informational state |
| Tidak Hadir | `#FEE2E2` | `#B91C1C` | Prior-day follow-up gap |
| Hadir Tanpa Jadwal | `#ECFEFF` | `#0F766E` | Unscheduled attendance review badge |
| Kandidat Break-first | `#FEF3C7` | `#B45309` | Candidate state, softer than confirmed break-first |
| Break-first | `#FFF7ED` | `#C2410C` | Confirmed or trusted break-first-related state |
| Terlambat | `#FEF3C7` | `#92400E` | Normal late state |

Tone rule:
- Current-day informational states (`Belum masuk`) should stay calmer than true follow-up gaps (`Tidak hadir`).
- `Kandidat break-first` and confirmed `Break-first` must not share the exact same label or color treatment.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Primary CTA | `Konfirmasi Penugasan` |
| Empty state heading | `Belum Ada Jadwal Minggu Ini` |
| Empty state body | `Tap sel kosong atau gunakan bulk assign untuk mulai menyusun jadwal minggu ini.` |
| Error state | `Jadwal belum bisa disimpan. Periksa band, jam wajib, dan koneksi lalu coba lagi.` |
| Destructive confirmation | `Hapus penugasan`: `Penugasan untuk hari ini akan dihapus dari jadwal.` |

Additional locked copy:

| Element | Copy |
|---------|------|
| Policy summary card title | `Aturan Jadwal Minggu Ini` |
| Policy summary helper | `Band dan jam wajib menjadi acuan utama. Jam lama hanya tampil sebagai petunjuk kecil bila masih dibutuhkan.` |
| Bulk review title | `Tinjau Penugasan` |
| Bulk review helper | `Periksa band, jam wajib, dan batas telat sebelum konfirmasi.` |
| Bulk review row label | `Band`, `Jam wajib`, `Batas telat`, `Break-first` |
| Recap filter labels | `Semua`, `Terlambat`, `Terlambat Normal`, `Break-first`, `Kandidat Break-first`, `Belum Masuk`, `Tidak Hadir`, `Hadir Tanpa Jadwal` |
| Recap badge labels | `Terlambat`, `Break-first`, `Kandidat break-first`, `Belum masuk`, `Tidak hadir`, `Hadir tanpa jadwal`, `Sakit`, `Izin`, `Cuti`, `Libur` |
| No-show reason copy | `Tidak ada scan pada hari kerja yang sudah selesai.` |
| Current-day informational reason copy | `Hari kerja masih berjalan dan belum ada scan masuk.` |
| Break-first helper copy | `Masih dalam jendela break-first, menunggu konfirmasi.` |

Language contract:
- All user-facing copy stays in Bahasa Indonesia.
- Use operational wording, not payroll or disciplinary language.
- Do not use red/yellow performance taxonomy words in this phase.

---

## Component Inventory

### 1. Schedule Policy Summary Card

File target: `lib/screens/admin/widgets/schedule_policy_summary_card.dart`

Purpose:
- Sits below the date-range header and above the legend/grid.
- Carries the policy detail that should not be repeated inside every cell.

Required content blocks:
- `Batas telat`: exactly `Pagi 07:00`, `Siang 10:00`, `Sore 15:00`
- `Jam wajib default`: exactly `FULLTIME 10j`, `PARTTIME 9j`
- `Break-first`: concise windows derived from the current contract policy, not a long paragraph

Visual contract:
- White card on white/surface scaffold with 1px `AppColors.border` border and 12px radius
- 16px padding
- Section title at 14sp w700
- Each policy row uses a label on the left and compact semantic chips or text blocks on the right

### 2. Weekly Schedule Grid Cell

Primary purpose:
- Make `band + required hours` the visible meaning of a scheduled day

Required cell hierarchy:
1. Primary label: `Pagi - 10j`, `Siang - 9j`, `Sore - 10j`, or `Libur`
2. Secondary hint: `07:00 batas telat`, `10:00 batas telat`, `15:00 batas telat`, or leave-specific hint
3. Exact time hint, if still shown anywhere, must be tertiary and must not replace the primary label

Cell behavior contract:
- Empty state keeps the current compact `+` affordance
- Assigned state remains a tappable chip/card inside the cell
- Chip should allow two lines when needed instead of truncating the policy hint into illegibility

### 3. Bulk Review Sheet / Dialog

Purpose:
- Insert a lightweight review step after band choice in bulk mode, before the write is committed

Required structure:
- Title: `Tinjau Penugasan`
- Subtitle/helper: `Periksa band, jam wajib, dan batas telat sebelum konfirmasi.`
- One compact summary block per chosen band that shows:
  - selected band
  - default required hours by contract
  - lateness cutoff
  - break-first deadline summary
- Actions:
  - primary filled button: `Konfirmasi Penugasan`
  - secondary text button: `Batal`

This must feel like a confirmation checkpoint, not a replacement for the existing fast grid workflow.

### 4. Admin Policy Recap Filters and Badges

Surface:
- `AdminReportsScreen` Rekap Harian tab

Required layout:
- Horizontal, scrollable filter chip row above the recap list
- Keep the existing per-scan tab intact; this phase only upgrades the recap side
- Each recap card should show one reusable policy badge plus one short reason line when needed

Severity hierarchy:
- `Belum masuk` = neutral/warning-light
- `Terlambat` = warning
- `Kandidat break-first` = softer orange warning
- `Break-first` = stronger orange emphasis
- `Tidak hadir` = strongest danger emphasis

---

## Interaction Contract

### Scheduler interactions
- Tapping an empty cell opens the fast band picker.
- Fast band selection remains the primary interaction; no full-form detour for common edits.
- In bulk mode, band selection routes to the review step before data is written.
- Removing an assigned cell stays a direct tap on the assigned surface, matching the current workflow.

### Recap interactions
- Rekap filter chips update the list immediately and preserve the active outlet/date context.
- Switching between `Per Scan` and `Rekap Harian` stays a top-level tab action; do not bury filters inside dialogs.
- Current-day informational states must not visually overpower follow-up gaps.

### Responsive behavior
- On narrow screens, filter chips and the policy summary row can scroll horizontally.
- On tablet-width layouts, the summary card may use a 2-column internal layout, but the visual order remains:
  1. lateness cutoffs
  2. required hours
  3. break-first rules
- Grid cells may wrap to 2 lines, but the chip must remain center-aligned and tappable.

---

## Layout Contract

High-level order for the scheduler screen in this phase:

1. Existing AppBar
2. Existing week-range header
3. `SchedulePolicySummaryCard`
4. Existing `ScheduleLegend`
5. Weekly grid (`ScheduleTableView`)
6. Existing FAB stack

High-level order for the recap screen in this phase:

1. Existing date / outlet controls
2. Existing tab bar
3. Recap-only horizontal filter row
4. Recap cards with badge + reason copy

Do not insert dense explanatory paragraphs between the header and the grid. Policy content belongs in the summary card and review step, not as wall-of-text chrome.

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| Flutter / Material built-ins | Card, Chip, Dialog, TabBar, Icon, Button, Checkbox | not required |
| `google_fonts` | Plus Jakarta Sans only | already in repo |
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

**Approval:** approved 2026-03-26
