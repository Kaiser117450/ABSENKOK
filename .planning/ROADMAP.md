# Roadmap: Absensi Enakko

## Milestones

- ✅ **v6.1 Employee Portal** — Phases 37-39 shipped 2026-03-23. Archive: [`milestones/v6.1-ROADMAP.md`](milestones/v6.1-ROADMAP.md)
- 🚧 **v6.2 Dashboard & Report Foundation** — Phases 40-41 planned 2026-03-23.

## Current Milestone: v6.2 Dashboard & Report Foundation

**Goal:** Restore the preferred admin dashboard flow, keep chain-wide network visibility on a dedicated screen, refresh Enakko branding, and harden large-volume attendance PDF exports before future feature work.

### Phase 40: Admin Dashboard Restoration & Brand Refresh

**Goal:** Make the classic operational dashboard the default admin landing again, while preserving a dedicated path to the chain-wide network control center and updating the dashboard brand asset.
**Depends on:** None
**Requirements:** `DASH-01`, `DASH-02`, `DASH-03`, `BRAND-01`

**Success criteria:**
1. Full admin opens `/admin/dashboard` and sees the classic admin dashboard, while kepala gerai behavior stays outlet-scoped.
2. Ringkasan jaringan and status per gerai are still available through a dedicated action/screen instead of replacing the default admin landing surface.
3. The admin dashboard header uses `assets/images/logo_enakko.png` without breaking the existing layout on phone and tablet widths.

### Phase 41: PDF Report Reliability & Count Metrics

**Goal:** Keep Rekap Harian PDF summaries reliable on large exports and replace percentage-based attendance summaries with concrete operational counts.
**Depends on:** Phase 40
**Requirements:** `PDF-01`, `PDF-02`, `PDF-03`

**Success criteria:**
1. Rekap Harian PDF still shows per-employee summary content when the selected date range generates hundreds of rows.
2. Report-level summary cards show count-based values for hadir, tidak absen, and belum absen pulang in the selected range.
3. Per-employee summary rows show count-based attendance/absence/open-shift values while preserving supporting time context that remains useful for admins.

## Traceability

| Requirement | Phase |
|-------------|-------|
| DASH-01 | Phase 40 |
| DASH-02 | Phase 40 |
| DASH-03 | Phase 40 |
| BRAND-01 | Phase 40 |
| PDF-01 | Phase 41 |
| PDF-02 | Phase 41 |
| PDF-03 | Phase 41 |

## Notes

- Current active milestone starts at phase `40`.
- v6.1 was archived with accepted verification debt. See [`milestones/v6.1-MILESTONE-AUDIT.md`](milestones/v6.1-MILESTONE-AUDIT.md) for the final audit snapshot.
