---
phase: 60
slug: rollout-payroll-acceptance
status: approved
shadcn_initialized: false
preset: none
created: 2026-03-28
reviewed_at: 2026-03-28T16:02:13.0791837+08:00
---

# Phase 60 - UI Design Contract

> Visual and interaction contract for Phase 60: Rollout & Payroll Acceptance.
> Generated from the v8 rollout requirement, the approved Phase 58 and 59 UI contracts, and the existing Flutter admin plus Astro portal evidence surfaces.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (Flutter Material 3 admin shell + existing Astro/Tailwind portal shell + exported spreadsheet/PDF artifacts) |
| Preset | not applicable |
| Component library | Flutter Material 3 with existing `AppCard` / recap widgets; existing Astro portal cards remain read-only evidence surfaces |
| Icon library | Material Icons in Flutter/PDF, inline SVG icons in the Astro portal shell |
| Font | Plus Jakarta Sans for Flutter/PDF, Inter for the existing portal shell |

Source of truth:
- `.planning/REQUIREMENTS.md` for `OPS-01`
- `.planning/ROADMAP.md` for the Phase 60 rollout and acceptance goal
- `.planning/phases/58-payroll-matrix-spreadsheet-export/58-UI-SPEC.md`
- `.planning/phases/59-pdf-portal-parity/59-UI-SPEC.md`
- `.planning/phases/59-pdf-portal-parity/59-CONTEXT.md`
- `.planning/phases/59-pdf-portal-parity/59-RESEARCH.md`
- `docs/android-release-runbook.md` for the operator-facing rollout rhythm
- `lib/screens/admin/admin_reports_screen.dart` and the shipped payroll recap/export surfaces as the baseline admin shell

Phase 60 does not introduce a new employee-facing design system, a new portal theme, or a new export visual language. The only new UI allowed in this phase is an operator-facing acceptance layer that sits inside the existing admin reporting shell and references already-shipped portal, spreadsheet, and PDF artifacts as evidence.

---

## Spacing Scale

Declared values (must be multiples of 4):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Inline status-dot gaps, checklist bullet spacing, compact metadata separators |
| sm | 8px | Scenario-chip spacing, evidence tag spacing, helper-copy separation |
| md | 16px | Default card padding, checklist row padding, toolbar spacing |
| lg | 24px | Section spacing between rollout summary, scenario matrix, and evidence blocks |
| xl | 32px | Major separation between acceptance sections on desktop layouts |
| 2xl | 48px | Footer action rhythm and minimum breathing room around the final approval area |
| 3xl | 64px | Page-level vertical spacing for the admin acceptance screen |

Exceptions:
- No spacing exceptions are allowed for new Phase 60 surfaces.
- New acceptance cards and checklist rows must snap to the declared token scale only.
- Divider thickness, corner radius, and accessibility hit-target rules are design-system constraints, not additions to the spacing scale.

Spacing source:
- The 4/8/16/24/32/48/64 rhythm is inherited from the approved Phase 58 and 59 UI contracts.
- The acceptance layer reuses the existing admin recap card language while snapping new layout spacing to `sm`, `md`, `lg`, `xl`, `2xl`, and `3xl`.

---

## Typography

Use only 4 sizes and 2 weights in new Phase 60 surfaces.

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| Body | 13px | w400 | 1.45 |
| Label | 11px | w700 | 1.25 |
| Heading | 18px | w700 | 1.2 |
| Display | 24px | w700 | 1.1 |

Phase 60 hierarchy:

| Element | Size | Weight | Color |
|---------|------|--------|-------|
| Acceptance screen title | 18px | w700 | `AppColors.textPrimary` |
| Rollout readiness headline (`Siap payroll`, `Butuh verifikasi`) | 24px | w700 | semantic foreground |
| Checklist section title | 18px | w700 | `AppColors.textPrimary` |
| Scenario row label (`Full-time`, `Outlet 24 jam`, `Break-first`) | 13px | w700 | `AppColors.textPrimary` |
| Scenario supporting note and evidence helper | 13px | w400 | `AppColors.textSecondary` |
| Status chip label (`Lolos`, `Tertunda`, `Blokir`) | 11px | w700 | semantic foreground |
| Footer CTA label (`Tandai Siap Payroll`) | 13px | w700 | `AppColors.textOnPrimary` |

Typography rules:
- Flutter and generated PDF evidence keep Plus Jakarta Sans from the existing theme; portal evidence surfaces keep their current Inter shell without introducing a third font family.
- Do not introduce a third font weight or micro sizes smaller than 11px.
- The readiness headline is the only display-style treatment. Scenario rows, evidence notes, and status chips must stay compact and operational.
- Export filenames, environment labels, and scenario tags must reuse the `Label` role instead of adding a fifth type size.

---

## Color

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `#FFFFFF` | Acceptance cards, checklist surfaces, matrix and document preview panels |
| Secondary (30%) | `#F9FAFB` | Page canvas, neutral summary panels, pending-state shells, disabled review areas |
| Accent (10%) | `#DC2626` | Primary `Tandai Siap Payroll` CTA, active scenario focus, approved export-evidence emphasis |
| Destructive | `#B91C1C` | Database-change confirmation, blocked rollout actions only |

Accent reserved for:
- the primary `Tandai Siap Payroll` action
- the active scenario row or selected evidence drill-in
- a single keyline or badge that marks the currently reviewed parity artifact
- keyboard focus ring and operator-review emphasis states

Do not use the accent color for every checklist row, every clickable label, or all status chips. Passed, pending, and blocked scenarios must use explicit semantic state colors instead of overloading the accent.

### Acceptance state semantics

| State | Background | Foreground | Usage |
|-------|------------|------------|-------|
| Ready / passed | `#DCFCE7` | `#166534` | Checklist complete, parity confirmed, scenario accepted |
| Needs review | `#FEF3C7` | `#92400E` | Pending scenario, operator follow-up, compatibility warning |
| Blocked | `#FEE2E2` | `#B91C1C` | Parity mismatch, rollout blocker, missing evidence |
| Informational | `#ECFEFF` | `#0F766E` | WITA note, additive-only reminder, read-only evidence guidance |

Tone rules:
- Acceptance status colors communicate rollout readiness, not employee payroll outcomes.
- When showing portal, spreadsheet, PDF, or admin evidence previews, preserve the shipped Phase 59 payroll semantics inside those artifacts.
- The destructive family is reserved for irreversible or production-impacting actions only, especially any database-change confirmation step.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Primary CTA | `Tandai Siap Payroll` |
| Secondary CTA | `Unduh Bukti Validasi` |
| Empty state heading | `Belum ada bukti validasi payroll` |
| Empty state body | `Jalankan checklist rollout dan verifikasi minimal satu skenario agar payroll baru belum dipakai tanpa bukti parity.` |
| Error state | `Validasi payroll belum bisa dimuat. Muat ulang data rollout. Jika masih gagal, hentikan penggunaan payroll baru dan hubungi admin.` |
| Destructive confirmation | `Terapkan perubahan database`: `Perubahan database harus additive dan hanya dijalankan setelah backup, checklist, dan persetujuan operator lengkap. Lanjutkan?` |

Additional locked copy:

| Element | Copy |
|---------|------|
| Screen title | `Rollout Payroll` |
| Screen helper | `Pastikan rollout aman, skenario kritis lolos, dan semua ekspor tetap selaras sebelum payroll dipakai untuk gaji.` |
| Readiness pass headline | `Payroll siap dipakai` |
| Readiness blocked headline | `Payroll belum aman dipakai` |
| Rollout banner title | `Mode rollout additive` |
| Rollout banner body | `Perubahan produksi harus additive-only dan semua perubahan database wajib lewat konfirmasi operator.` |
| Scenario section title | `Skenario wajib` |
| Scenario section helper | `Verifikasi setiap skenario dengan hasil admin, spreadsheet, PDF, dan portal untuk hari kerja yang sama.` |
| Evidence section title | `Bukti parity` |
| Evidence helper | `Bandingkan label utama, tag singkat, dan severity di semua artefak sebelum menyetujui payroll.` |
| Scenario labels | `Full-time`, `Part-time`, `Lembur`, `Outlet 24 jam`, `Outlet normal`, `Break-first`, `No-show` |
| Evidence columns | `Admin`, `Spreadsheet`, `PDF`, `Portal`, `Status` |
| Pending note | `Masih butuh verifikasi` |
| Passed note | `Parity terkonfirmasi` |
| Blocked note | `Ada perbedaan hasil antar artefak` |

Language rules:
- All new operator-facing copy stays in Bahasa Indonesia.
- Use operational, calm language. Do not use threatening or disciplinary wording.
- Database and rollout copy must be explicit about risk, but still give a clear next action.
- Employee-facing portal copy must not be rewritten in this phase; the portal remains a read-only evidence surface.

---

## Visual Hierarchy

Primary focal point:
1. rollout readiness panel showing overall state (`Payroll siap dipakai` or `Payroll belum aman dipakai`) plus the additive-only warning

Secondary focal points:
2. required scenario checklist covering full-time, part-time, overtime, 24-hour outlet, normal outlet, break-first, and no-show cases
3. parity evidence table comparing admin matrix, spreadsheet export, PDF export, and portal presentation for the same logical day

Tertiary information:
4. notes about WITA server-time, overnight handling, and fallback compatibility
5. export links, filenames, or preview metadata

Hierarchy rules:
- The overall readiness state must be visible without scrolling past the first screenful.
- The scenario matrix is the main operational workspace; it must feel denser than a marketing dashboard and cannot be replaced by oversized summary numerals.
- Any icon-only affordance must include label text or tooltip fallback.
- Portal, spreadsheet, and PDF previews are evidence surfaces, not the primary workspace. They must stay visually subordinate to the checklist and parity verdicts.

---

## Component Inventory

### 1. Rollout Readiness Banner

Surface:
- existing Flutter admin reporting shell or adjacent operator-only acceptance screen

Purpose:
- Communicate whether the payroll rollout is safe to use and restate the additive-only rule before any approval action is available.

Required structure:
1. readiness headline
2. one-line helper copy
3. additive-only banner
4. compact summary of passed / pending / blocked scenarios

Visual contract:
- White card with a semantic left keyline or badge.
- Readiness headline is the visual anchor.
- The additive-only banner uses the informational state family, never the primary accent.

### 2. Scenario Acceptance Matrix

Purpose:
- Track required evidence for the seven must-pass scenarios: full-time, part-time, overtime, 24-hour outlet, normal outlet, break-first, and no-show.

Required structure:
1. scenario label
2. outlet or test-context helper
3. status chip
4. evidence links or preview entry points for admin / spreadsheet / PDF / portal
5. operator note field or summary line

Rules:
- The matrix stays one row per scenario.
- Each scenario must show an explicit status; blank rows are not allowed.
- Scenarios cannot be marked passed until all four artifact columns are available or explicitly marked not applicable with justification.

### 3. Parity Evidence Table

Purpose:
- Compare the same logical workday across the admin matrix, spreadsheet export, PDF export, and portal presentation.

Required structure:
1. employee and logical-date context
2. four artifact columns: admin, spreadsheet, PDF, portal
3. status verdict column
4. compact mismatch note when parity fails

Rules:
- The table is read-only evidence, not an editing surface.
- The primary label, short tags, and severity family must match across all four artifacts.
- If parity fails, the row turns blocked and the final approval CTA remains disabled.

### 4. Database Confirmation Dialog

Purpose:
- Gate any production database change behind an explicit operator acknowledgement.

Required structure:
1. destructive title
2. reminder that the change must be additive-only
3. checklist prerequisites (`backup`, `review`, `approval`) listed inline
4. explicit confirmation action plus a safe cancel action

Rules:
- This is the only destructive or irreversible interaction defined in this phase.
- The confirm button uses the destructive color, not the standard accent.
- The dialog must never appear automatically on page load.

### 5. Validation Export Summary

Purpose:
- Package the acceptance evidence into a shareable operator artifact after all scenarios pass.

Required structure:
1. validation timestamp
2. operator-ready summary line
3. passed scenario count
4. link or button to download the evidence bundle

Rules:
- This summary stays secondary to the scenario matrix.
- Filenames and metadata remain compact and operational.
- No GPS, queue-order, or low-signal technical fields are allowed in the exported acceptance summary.

---

## Interaction Contract

### Acceptance interactions
- `Tandai Siap Payroll` is disabled until every required scenario is passed and there are zero blocked parity rows.
- Scenario rows may expand or drill in to show evidence, but they must not become separate wizard screens.
- Passed scenarios remain editable only for notes or re-validation; they cannot silently regress to passed after a mismatch appears.

### Evidence interactions
- Opening admin, spreadsheet, PDF, or portal evidence must keep the operator anchored to the acceptance screen.
- Evidence previews are read-only.
- Mismatch states must show which artifact diverged and what the operator should review next.

### Rollout safety interactions
- Any production-impacting action requires the destructive confirmation dialog.
- The destructive action must not be the primary default focus if prerequisites are missing.
- If the rollout is blocked, the UI must explain what is missing instead of showing a generic failure state.

---

## Layout Contract

High-level order for the acceptance surface:

1. existing admin shell header and filters if the flow lives in the recap area
2. rollout readiness banner
3. additive-only reminder
4. scenario acceptance matrix
5. parity evidence table
6. validation export summary
7. footer action bar with `Tandai Siap Payroll` primary and `Unduh Bukti Validasi` secondary

Rules:
- Keep the layout single-column on mobile and two-zone on desktop only when the checklist and evidence table can remain visible together.
- Do not create a separate portal-facing acceptance page.
- Do not replace the existing recap/export screens; this phase layers acceptance on top of them.

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| Flutter / Material built-ins | `AppCard`, `FilledButton`, `OutlinedButton`, `AlertDialog`, `DataTable`, `Icon`, existing recap widgets | not required |
| Existing repo packages | `google_fonts`, `pdf`, `share_plus`, `two_dimensional_scrollables`, Astro/Tailwind utilities already in repo | already in repo |
| Third-party UI registries | none | not applicable |

No shadcn or third-party component registry work is allowed in this phase. Phase 60 must stay within the existing Flutter admin shell and the already-shipped portal/export surfaces.

---

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS
- [x] Dimension 2 Visuals: PASS
- [x] Dimension 3 Color: PASS
- [x] Dimension 4 Typography: PASS
- [x] Dimension 5 Spacing: PASS
- [x] Dimension 6 Registry Safety: PASS

**Approval:** approved 2026-03-28
