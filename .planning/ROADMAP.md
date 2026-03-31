# Roadmap: Absensi Enakko

## Shipped Milestones

- ✅ **v8.0 Strict Attendance & Payroll Reporting** — Phases 54-60 plus 58.1, shipped 2026-03-31 ([roadmap archive](.planning/milestones/v8.0-ROADMAP.md), [requirements archive](.planning/milestones/v8.0-REQUIREMENTS.md), [audit](.planning/milestones/v8.0-MILESTONE-AUDIT.md))
- ✅ **v7.1 Security Hardening** — Phases 50-53, shipped 2026-03-25 ([roadmap archive](.planning/milestones/v7.1-ROADMAP.md), [requirements archive](.planning/milestones/v7.1-REQUIREMENTS.md))
- ✅ **v7.0 Android Release Hardening** — Phases 46-49 plus 48.1, shipped 2026-03-25 ([roadmap archive](.planning/milestones/v7.0-ROADMAP.md), [requirements archive](.planning/milestones/v7.0-REQUIREMENTS.md))

## Active Milestone

No new milestone is defined yet.

The remaining non-milestone operational work is the intentional manual Phase 60 rollout review before payroll depends on the new outputs.

## Current Position

- Latest shipped milestone: **v8.0 Strict Attendance & Payroll Reporting**
- Product state: payroll reporting is now contract-aware, server-time authoritative, overnight-safe, and parity-aligned across Admin, Spreadsheet, PDF, and Portal
- Database guard: any production SQL apply step still requires explicit user confirmation and must stay additive-only
- Next planning step: run `$gsd-new-milestone` when ready to define the next product scope

## Latest Shipment Summary

v8.0 delivered:

- explicit employee contracts and outlet operating modes as first-class attendance inputs
- band-first schedule policy with required-hours, lateness, break-first, and no-show handling
- authoritative WITA scan time with offline-safe replay
- strict recap evaluation with manager exemption and payroll-facing detail signals
- payroll matrix plus spreadsheet export, portal/PDF parity, and legacy no-schedule compatibility
- rollout acceptance tooling with a readiness panel, fixture pack, and validation bundle export

---
_For current project status, see `.planning/PROJECT.md`_
_For full milestone history, see `.planning/MILESTONES.md`_
