# Milestone v6.2 Requirements

**Status:** ACTIVE
**Version:** v6.2
**Milestone:** Dashboard & Report Foundation
**Coverage target:** `7/7` requirements mapped

## 1. Admin Dashboard Flow
- [ ] **DASH-01**: Full admin lands on the classic admin dashboard at `/admin/dashboard` instead of the chain-wide network control center.
- [ ] **DASH-02**: The admin dashboard provides a dedicated action to open the separate ringkasan jaringan and status per gerai screen without removing the classic operational dashboard content.
- [ ] **DASH-03**: Kepala gerai remains limited to outlet-scoped admin visibility and does not gain access to full-admin-only chain-wide network data.

## 2. Brand Refresh
- [ ] **BRAND-01**: The admin dashboard hero/header renders the official `assets/images/logo_enakko.png` asset instead of the utensil-only mark.

## 3. Attendance PDF Reliability
- [ ] **PDF-01**: Rekap Harian PDF keeps the per-employee summary visible even when the selected export range produces hundreds of attendance rows.
- [ ] **PDF-02**: Rekap Harian PDF summary cards show concrete counts for hadir, tidak absen, and belum absen pulang within the selected date range instead of attendance percentage.
- [ ] **PDF-03**: Rekap Harian PDF per-employee summary rows show count-based values for hadir, tidak absen, and belum absen pulang while preserving useful supporting time context.

## Future Requirements
- `ATTN-01`: Employee attendance recap inside the portal
- `REQ-01`: Employee submits time-off or absence requests
- `REQ-02`: Manager/admin approves employee requests
- `NOTF-01`: Shift reminders or notifications
- `GRID-D1`: Schedule grid tap-to-cycle shift assignment
- `GRID-D2`: Schedule grid copy-week feature
- `GRID-D3`: Schedule grid today-column highlight

## Out of Scope
- New portal features beyond carrying forward the deferred backlog
- Database schema changes for this foundation pass unless a defect proves a non-breaking additive migration is strictly required
- Redesigning analytics/chart pages outside the navigation and summary access changes required by `DASH-02`

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DASH-01 | Phase 40 | Planned |
| DASH-02 | Phase 40 | Planned |
| DASH-03 | Phase 40 | Planned |
| BRAND-01 | Phase 40 | Planned |
| PDF-01 | Phase 41 | Planned |
| PDF-02 | Phase 41 | Planned |
| PDF-03 | Phase 41 | Planned |

## Coverage Summary

- Total requirements: 7
- Phase 40 requirements: 4
- Phase 41 requirements: 3
- All active requirements mapped: yes
