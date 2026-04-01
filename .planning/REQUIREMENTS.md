# Requirements: Absensi Enakko

**Defined:** 2026-03-31
**Core Value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.

## Milestone v8.1 Requirements

### Recap Recovery

- [x] **RECAP-05**: Admin Rekap Harian and pending views continue to show usable day rows for existing attendance data even when some dates still have no `schedule_entries`.
- [x] **RECAP-06**: Compatibility rows for no-schedule days preserve logical-day grouping, contract-based required hours, and honest incomplete states without fabricating late or absence signals.

### Strict Rule Retention

- [x] **RECAP-07**: Break-first, excess-break, and other strict contract-aware recap rules remain visible for days where strict evaluation data exists; compatibility handling must not downgrade those days into generic no-schedule rows.

### Export Parity

- [ ] **REPORT-04**: Spreadsheet export uses the same corrected merged recap dataset as admin Rekap Harian while preserving compact payroll-facing fields, current color semantics, and per-employee summary counts.
- [ ] **REPORT-05**: Payroll PDF uses the same corrected merged recap dataset as admin Rekap Harian and spreadsheet export without reintroducing technical scan fields or a second reporting interpretation.

### Schedule Gap Notifications

- [ ] **SCHED-05**: Kepala gerai can see outlet-scoped notifications for employee/date schedule gaps that still need to be filled, and those notices do not block report generation or mutate payroll penalty semantics.

## Deferred Product Requirements

### Operational Follow-Ups

- **NOTIF-01**: Empty-schedule notices can escalate into WhatsApp, email, or recurring reminder workflows.
- **SCHED-06**: System can backfill or bulk-repair historical missing schedules automatically from trusted templates.

### Payroll Follow-Ups

- **PAY-01**: System calculates salary, lembur pay, or deduction totals automatically from recap outcomes.
- **PAY-02**: System generates payslips or downloadable payroll settlement documents.
- **PAY-03**: Manager can approve, reject, or adjust overtime classification before payroll lock.

### Workforce Workflow Follow-Ups

- **CORR-01**: Employee can submit attendance correction requests for late, break, or missing scan disputes.
- **CORR-02**: Manager can resolve disputed break-first or overnight cases from a dedicated approval surface.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Turning off strict reporting wholesale | User still wants break-first and excess-break rules to remain active where the data supports them |
| Requiring full schedule backfill before reports work again | This milestone exists to make current legacy data usable now |
| Multi-channel reminder delivery beyond the in-app kepala gerai notice | Defer until the recap baseline is trusted again |
| Automatic payroll amount calculation or payslip generation | v8.1 is still limited to salary-ready attendance evidence and exports |
| GPS, latitude/longitude, or raw technical scan columns in payroll recap exports | User explicitly wants compact payroll-facing reports |
| Free-form per-employee shift clock editing | The product direction remains fixed business rules with shift bands, not arbitrary daily time authoring |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| RECAP-05 | Phase 61 | Complete |
| RECAP-06 | Phase 61 | Complete |
| RECAP-07 | Phase 61 | Complete |
| REPORT-04 | Phase 63 | Pending |
| REPORT-05 | Phase 63 | Pending |
| SCHED-05 | Phase 62 | Pending |

**Coverage:**
- v8.1 requirements: 6 total
- Mapped to phases: 6
- Unmapped: 0

---
*Requirements defined: 2026-03-31*
*Last updated: 2026-04-01 after Phase 61 completion*
