# Requirements: Absensi Enakko

**Defined:** 2026-03-23
**Milestone:** v6.3 Employee Attendance Recap
**Core Value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.

## v6.3 Requirements

### Attendance History

- [ ] **ATTN-01**: Employee can open an attendance recap inside the existing portal and see recent attendance days without leaving the employee-facing shell.
- [x] **ATTN-02**: Each recap day shows the recorded attendance outcome together with the available attendance timestamps for that logical workday.
- [x] **ATTN-03**: Portal attendance recap applies the product's existing logical-day and overnight handling so cross-day attendance appears on the correct workday.

### Summary & Exceptions

- [ ] **ATTN-04**: Employee can see month-to-date summary counts for the attendance states surfaced in the recap.
- [ ] **ATTN-05**: Employee can identify days that need follow-up, including incomplete attendance outcomes and scheduled days without a completed attendance record.

### Portal Experience

- [ ] **PORT-03**: Portal attendance recap is usable on a phone-sized browser and fits the existing employee portal shell.
- [ ] **PORT-04**: Portal attendance recap shows clear loading, empty, and error states when recap data is unavailable.

## v6.4+ Candidate Requirements

### Attendance Workflow

- **ATTN-06**: Employee can filter attendance recap by custom date range or prior month.
- **ATTN-07**: Employee can submit an attendance correction or dispute request from an exception day.

### Requests & Approvals

- **REQ-01**: Employee can submit time-off or absence requests through the portal.
- **REQ-02**: Manager or admin can approve or reject employee requests with an auditable status change.

### Notifications

- **NOTF-01**: Employee receives reminders or status notifications for upcoming work or request changes.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Payroll-grade attendance exports or salary calculations | v6.3 is about attendance visibility, not payroll policy or finance output |
| Employee-edited attendance records | Requires approval, audit trail, and mutation safeguards outside this read-only milestone |
| Real-time push or live-stream attendance updates | Adds complexity without materially improving the recap job-to-be-done |

## Traceability

Roadmap mapping for the approved v6.3 milestone:

| Requirement | Phase | Status |
|-------------|-------|--------|
| ATTN-01 | Phase 43 | Pending |
| ATTN-02 | Phase 42 | Complete |
| ATTN-03 | Phase 42 | Complete |
| ATTN-04 | Phase 43 | Pending |
| ATTN-05 | Phase 44 | Pending |
| PORT-03 | Phase 43 | Pending |
| PORT-04 | Phase 44 | Pending |

**Coverage:**
- v6.3 requirements: 7 total
- Mapped to phases: 7
- Unmapped: 0

---
*Requirements defined: 2026-03-23*
*Last updated: 2026-03-23 after roadmap creation for milestone v6.3*
