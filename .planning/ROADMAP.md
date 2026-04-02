# Roadmap: Absensi Enakko

## Shipped Milestones

- ✅ **v8.0 Strict Attendance & Payroll Reporting** — Phases 54-60 plus 58.1, shipped 2026-03-31 ([roadmap archive](.planning/milestones/v8.0-ROADMAP.md), [requirements archive](.planning/milestones/v8.0-REQUIREMENTS.md), [audit](.planning/milestones/v8.0-MILESTONE-AUDIT.md))
- ✅ **v7.1 Security Hardening** — Phases 50-53, shipped 2026-03-25 ([roadmap archive](.planning/milestones/v7.1-ROADMAP.md), [requirements archive](.planning/milestones/v7.1-REQUIREMENTS.md))
- ✅ **v7.0 Android Release Hardening** — Phases 46-49 plus 48.1, shipped 2026-03-25 ([roadmap archive](.planning/milestones/v7.0-ROADMAP.md), [requirements archive](.planning/milestones/v7.0-REQUIREMENTS.md))

## Active Milestone

**v8.1 Reporting Recovery & Schedule Gap Notifications**

**Goal:** Restore trusted Rekap Harian continuity for legacy no-schedule data while preserving strict contract-aware report rules and keeping spreadsheet/PDF as the canonical salary-facing outputs.

## Proposed Roadmap

**3 phases** | **6 requirements mapped** | All covered

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|--------------|------------------|
| 61 | Recap Semantics Recovery | 2/2 | Complete    | 2026-04-01 |
| 62 | Schedule Gap Notices | 2/2 | Complete    | 2026-04-01 |
| 63 | Export Parity Re-lock | 2/2 | Complete   | 2026-04-02 |

### Phase 61: Recap Semantics Recovery

**Goal:** Recover trusted Rekap Harian behavior for no-schedule legacy data while preserving break-first, excess-break, and contract-aware strict semantics where they legitimately apply.

**Plan progress:** 2 of 2 plans complete (`61-01-SUMMARY.md` and `61-02-SUMMARY.md` created on 2026-04-01). Phase 61 is complete; Phase 62 can now focus on schedule-gap notices without reopening recap recovery semantics.

**Requirements:** `RECAP-05`, `RECAP-06`, `RECAP-07`

**Success criteria:**
1. Admin recap and pending flows show usable rows for legacy attendance days even when schedule entries are missing.
2. Compatibility rows preserve logical day, contract-based required hours, and honest incomplete states without fabricating late or absence penalties.
3. Days that already have valid strict evaluation keep their strict break-first, excess-break, and other contract-aware signals instead of degrading into generic no-schedule rows.
4. Mixed strict + fallback datasets remain overnight-safe for `TWENTY_FOUR_HOUR` outlets.

### Phase 62: Schedule Gap Notices

**Goal:** Surface missing schedule follow-up as outlet-scoped kepala gerai notices instead of recap-breaking enforcement.

**Plan progress:** 2 of 2 plans complete (`62-01-SUMMARY.md` and `62-02-SUMMARY.md` created on 2026-04-01). Phase 62 is complete; Phase 63 can now relock spreadsheet/PDF parity on top of the corrected recap dataset and the shipped dashboard notice flow.

**Requirements:** `SCHED-05`

**Success criteria:**
1. Kepala gerai can see which employee/date combinations still need schedule filling for their outlet scope.
2. Schedule-gap notices are operational follow-up only and do not change recap penalties, export colors, or pending semantics.
3. The notice surface is lightweight and non-blocking, matching the user's request for "notification saja".

### Phase 63: Export Parity Re-lock

**Goal:** Keep spreadsheet export and payroll PDF on the same corrected merged recap dataset used by admin recap.

**Requirements:** `REPORT-04`, `REPORT-05`

**Plans:** 2/2 plans complete

Plans:
- [x] `63-01-PLAN.md` - Restore the shared export parity fixtures and replace the stale `PayrollRecapTab` test seam.
- [x] `63-02-PLAN.md` - Re-lock spreadsheet and payroll PDF service tests onto the shared merged recap parity fixtures.

**Success criteria:**
1. Spreadsheet export uses the corrected merged recap dataset and preserves compact payroll-facing output plus summary counts.
2. Payroll PDF uses the same corrected merged recap dataset and preserves the same reporting meaning as admin recap and spreadsheet export.
3. Forbidden technical fields remain absent from spreadsheet and PDF outputs.
4. Mixed strict/fallback regression fixtures prove parity across admin recap, spreadsheet, and payroll PDF.

## Current Position

- Active milestone: **v8.1 Reporting Recovery & Schedule Gap Notifications**
- Latest shipped milestone: **v8.0 Strict Attendance & Payroll Reporting**
- Product state: recap continuity is restored, kepala gerai now receives non-blocking `Jadwal Kosong` follow-up notices, and export parity is re-locked across admin recap, spreadsheet, and payroll PDF
- Database guard: any production SQL apply step still requires explicit user confirmation and must stay additive-only
- Next execution step: run milestone verification/closeout now that all Phase 61-63 work is complete

---
_For current project status, see `.planning/PROJECT.md`_  
_For full milestone history, see `.planning/MILESTONES.md`_
