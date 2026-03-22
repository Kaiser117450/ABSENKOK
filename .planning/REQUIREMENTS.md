# Requirements: Absensi Enakko

**Defined:** 2026-03-22
**Core Value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.

## v6.1 Requirements

### Access & Provisioning

- [ ] **AUTH-01**: Admin can provision initial employee portal access for an existing employee using employee code plus password.
- [ ] **AUTH-02**: Employee can sign in to the portal using employee code plus password.
- [ ] **AUTH-03**: Employee session persists across refresh while protected portal routes reject unauthenticated access.
- [ ] **AUTH-04**: Employee can sign out of the portal without affecting kiosk or admin sessions.

### Identity Linking

- [ ] **LINK-01**: An authenticated portal user resolves to exactly one employee record before schedule data is shown.
- [ ] **LINK-02**: If no linked employee record exists, the portal shows a clear "account not linked" state instead of exposing schedule data.

### Schedule Visibility

- [ ] **SCHED-01**: Employee can view today's assigned shift with outlet, shift label, and start/end times.
- [ ] **SCHED-02**: Employee can view upcoming assigned shifts for at least the current week.
- [ ] **SCHED-03**: Overnight or cross-day shifts appear consistently with the system's existing logical-day rules.

### Portal Experience

- [ ] **PORT-01**: Portal schedule pages are usable on a phone-sized browser without relying on the admin schedule grid.
- [ ] **PORT-02**: Portal distinguishes loading, empty schedule, not-linked, and error states clearly.

## Future Requirements

### Attendance

- **ATTN-01**: Employee can view their own attendance recap alongside schedule data.

### Requests

- **REQ-01**: Employee can submit time-off or absence requests from the portal.
- **REQ-02**: Manager or admin can review and approve employee requests.

### Notifications

- **NOTF-01**: Employee receives reminders for upcoming shifts.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Employee schedule editing | v6.1 is read-only self-service, not collaborative planning |
| Admin analytics in the portal | Existing admin surfaces already own this workflow |
| Phone OTP login | Current employee data model does not guarantee phone data |
| Email-first login | Current focused release aligns better with existing employee_code data |
| Native employee mobile app | Web-first keeps scope aligned with the existing Astro website |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUTH-01 | Phase 37 | Pending |
| AUTH-02 | Phase 37 | Pending |
| AUTH-03 | Phase 37 | Pending |
| AUTH-04 | Phase 39 | Pending |
| LINK-01 | Phase 37 | Pending |
| LINK-02 | Phase 39 | Pending |
| SCHED-01 | Phase 38 | Pending |
| SCHED-02 | Phase 38 | Pending |
| SCHED-03 | Phase 38 | Pending |
| PORT-01 | Phase 39 | Pending |
| PORT-02 | Phase 39 | Pending |

**Coverage:**
- v6.1 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0

---
*Requirements defined: 2026-03-22*
*Last updated: 2026-03-22 after v6.1 roadmap drafting*
