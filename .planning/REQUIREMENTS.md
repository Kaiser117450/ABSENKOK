# Requirements: Absensi Enakko

**Defined:** 2026-03-25
**Core Value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.

## Milestone v7.1 Requirements

### Device Boundary

- [x] **SECDEV-01**: A kiosk device can only send heartbeat updates after successful outlet activation, and the heartbeat path cannot silently rebind that device to a different outlet.
- [x] **SECDEV-02**: Device rename and archive RPCs only execute for authenticated admin or kepala gerai callers whose outlet scope matches the target kiosk.
- [x] **SECSAFE-01**: Admin and kiosk device surfaces handle malformed or short kiosk UUID data without crashing the client.

### Access Control

- [x] **SECACC-01**: Dashboard and analytics SECURITY DEFINER RPCs reject missing or invalid role claims instead of allowing authenticated users with `NULL` app roles.
- [x] **SECACC-02**: Flutter admin session handling derives admin or kepala gerai access only from server-controlled `app_metadata`, never from writable `userMetadata`.
- [x] **SECACC-03**: Biometric admin re-entry only restores privileged UI access when the current Supabase session is still valid and still carries the expected server-issued role claim.

### Portal Surface

- [x] **SECPORT-01**: Protected `/portal` requests complete the auth guard before route handlers execute any sensitive reads or mutations.
- [x] **SECPORT-02**: Public employee search returns only the minimum data needed to let an employee choose their card and caps enumeration-friendly query behavior.
- [x] **SECPORT-03**: Portal account repair and recovery logic only restores mappings for confirmed `employee_portal` auth users with an explicit employee binding and must not overwrite an existing mapping opportunistically.

### Security Rollout

- [x] **SECOPS-01**: Operators have one additive rollout checklist for the SQL, Astro, and Flutter hardening changes that is safe to apply against the live production database.

## Deferred Product Requirements

### Employee Product Work

- **ATTN-06**: Employee can filter attendance recap by custom date range or prior month
- **ATTN-07**: Employee can submit an attendance correction or dispute request from an exception day
- **REQ-01**: Employee can submit time-off or absence requests through the portal
- **REQ-02**: Manager/admin can approve or reject employee requests with an auditable status change
- **NOTF-01**: Employee receives reminders or status notifications for upcoming work or request changes
- **GRID-D1**: Schedule grid tap-to-cycle shift assignment
- **GRID-D2**: Schedule grid copy-week feature
- **GRID-D3**: Schedule grid today-column highlight
- **LATE-01**: Keterlambatan automatic flagging vs shift start time

### Release Follow-Ups

- **AUTO-01**: Release automation can publish artifacts or GitHub releases after the local release lane is proven
- **PERF-01**: Build-speed optimization can reduce turnaround time without weakening release guarantees
- **SIZE-01**: APK size and runtime startup can be tuned after the signed release baseline is stable

## Out of Scope

| Feature | Reason |
|---------|--------|
| Remove passwordless employee portal sign-in | Explicit user decision for convenience this milestone, even though Codex Security flagged it |
| Require pre-created mapping for every portal login before entry is allowed | Would negate the intentionally passwordless-any-active-employee behavior |
| Switch portal logout from local scope to global session revocation | Current portal logout contract intentionally avoids signing out admin or kiosk sessions |
| New employee portal request/approval features | Deferred until the hardening work is closed |
| CI/CD or release automation follow-up work | Not part of this security milestone |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SECDEV-01 | Phase 50 | Complete |
| SECDEV-02 | Phase 50 | Complete |
| SECSAFE-01 | Phase 50 | Complete |
| SECACC-01 | Phase 51 | Complete |
| SECACC-02 | Phase 51 | Complete |
| SECACC-03 | Phase 51 | Complete |
| SECPORT-01 | Phase 52 | Complete |
| SECPORT-02 | Phase 52 | Complete |
| SECPORT-03 | Phase 52 | Complete |
| SECOPS-01 | Phase 53 | Complete |

**Coverage:**
- v7.1 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0

---
*Requirements defined: 2026-03-25*
*Last updated: 2026-03-25 after completing Phase 52 portal surface minimization*
